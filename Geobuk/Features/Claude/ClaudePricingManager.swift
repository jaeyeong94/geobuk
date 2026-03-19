import Foundation

/// Claude 모델별 가격 관리
/// 앱 시작 시 Anthropic 공식 문서에서 가격을 fetch하여 로컬에 캐시
@MainActor
@Observable
final class ClaudePricingManager {
    /// 모델별 가격 데이터
    private(set) var pricing: [String: ModelPricing] = [:]

    /// 마지막 업데이트 시각
    private(set) var lastUpdated: Date?

    /// 캐시 파일 경로
    private static let cachePath: String = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Geobuk")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pricing.json").path
    }()

    init() {
        loadCachedPricing()
        if pricing.isEmpty {
            loadDefaultPricing()
        }
    }

    // MARK: - 비용 계산

    /// 모델 ID로 비용 계산
    func calculateCost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int = 0,
        cacheWriteTokens: Int = 0
    ) -> Double {
        let p = resolvePricing(for: model)
        return Double(inputTokens) * p.inputPerToken
            + Double(outputTokens) * p.outputPerToken
            + Double(cacheReadTokens) * p.cacheReadPerToken
            + Double(cacheWriteTokens) * p.cacheWritePerToken
    }

    /// 모델 ID를 매칭하여 가격 조회 (부분 매칭 지원)
    func resolvePricing(for model: String) -> ModelPricing {
        // 정확한 매칭
        if let p = pricing[model] { return p }

        // 부분 매칭 (claude-opus-4-6 → opus-4-6)
        let normalized = model.lowercased()
        for (key, value) in pricing {
            if normalized.contains(key.lowercased()) { return value }
        }

        // 기본값 (sonnet 가격)
        return ModelPricing.defaultSonnet
    }

    // MARK: - Fetch & Cache

    /// Anthropic 문서에서 가격 fetch (앱 시작 시 호출)
    func fetchPricing() async {
        guard let url = URL(string: "https://platform.claude.com/docs/en/about-claude/pricing") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return }
            let parsed = parsePricingFromHTML(html)
            if !parsed.isEmpty {
                pricing = parsed
                lastUpdated = Date()
                saveCachedPricing()
            }
        } catch {
            // fetch 실패 시 캐시 또는 기본값 유지
        }
    }

    /// HTML에서 가격 테이블 파싱
    private func parsePricingFromHTML(_ html: String) -> [String: ModelPricing] {
        var result: [String: ModelPricing] = [:]

        // 테이블 행 패턴: | Model | Input | ... | Output |
        // 간단한 정규식으로 파싱
        let lines = html.components(separatedBy: "\n")
        for line in lines {
            let cells = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 6 else { continue }

            let modelName = cells[1]
                .replacingOccurrences(of: "[deprecated]", with: "")
                .replacingOccurrences(of: "(.*)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            guard modelName.hasPrefix("Claude") else { continue }
            guard let inputPrice = extractPrice(cells[2]),
                  let outputPrice = extractPrice(cells[cells.count - 2].isEmpty ? cells[cells.count - 1] : cells[cells.count - 2]) else {
                continue
            }

            let cacheWrite = extractPrice(cells[3]) ?? inputPrice * 1.25
            let cacheRead = extractPrice(cells[5]) ?? inputPrice * 0.1

            let modelId = modelNameToId(modelName)
            result[modelId] = ModelPricing(
                modelName: modelName,
                inputPerMTok: inputPrice,
                outputPerMTok: outputPrice,
                cacheWritePerMTok: cacheWrite,
                cacheReadPerMTok: cacheRead
            )
        }

        return result
    }

    /// "$3" / "$0.30" 형식에서 숫자 추출
    private func extractPrice(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " / MTok", with: "")
            .replacingOccurrences(of: "/MTok", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    /// 모델 이름 → API ID 변환
    private func modelNameToId(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "claude ", with: "claude-")
            .replacingOccurrences(of: " ", with: "-")
    }

    // MARK: - Cache

    private func saveCachedPricing() {
        let cache = CachedPricing(pricing: pricing, lastUpdated: lastUpdated ?? Date())
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: URL(fileURLWithPath: Self.cachePath))
    }

    private func loadCachedPricing() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.cachePath)),
              let cache = try? JSONDecoder().decode(CachedPricing.self, from: data) else { return }
        pricing = cache.pricing
        lastUpdated = cache.lastUpdated
    }

    // MARK: - Default Pricing (fallback)

    private func loadDefaultPricing() {
        pricing = [
            "claude-opus-4-6": ModelPricing(modelName: "Claude Opus 4.6", inputPerMTok: 5, outputPerMTok: 25, cacheWritePerMTok: 6.25, cacheReadPerMTok: 0.50),
            "claude-opus-4-5": ModelPricing(modelName: "Claude Opus 4.5", inputPerMTok: 5, outputPerMTok: 25, cacheWritePerMTok: 6.25, cacheReadPerMTok: 0.50),
            "claude-sonnet-4-6": ModelPricing(modelName: "Claude Sonnet 4.6", inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30),
            "claude-sonnet-4-5": ModelPricing(modelName: "Claude Sonnet 4.5", inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30),
            "claude-haiku-4-5": ModelPricing(modelName: "Claude Haiku 4.5", inputPerMTok: 1, outputPerMTok: 5, cacheWritePerMTok: 1.25, cacheReadPerMTok: 0.10),
        ]
        lastUpdated = Date()
    }
}

// MARK: - Models

struct ModelPricing: Codable, Sendable {
    let modelName: String
    let inputPerMTok: Double
    let outputPerMTok: Double
    let cacheWritePerMTok: Double
    let cacheReadPerMTok: Double

    var inputPerToken: Double { inputPerMTok / 1_000_000 }
    var outputPerToken: Double { outputPerMTok / 1_000_000 }
    var cacheWritePerToken: Double { cacheWritePerMTok / 1_000_000 }
    var cacheReadPerToken: Double { cacheReadPerMTok / 1_000_000 }

    static let defaultSonnet = ModelPricing(
        modelName: "Claude Sonnet", inputPerMTok: 3, outputPerMTok: 15,
        cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30
    )
}

private struct CachedPricing: Codable {
    let pricing: [String: ModelPricing]
    let lastUpdated: Date
}
