import SwiftUI

/// 시스템 모니터 패널 — CPU 코어 히트맵, GPU, 메모리/Swap 바, 디스크, 네트워크 버블, Top 프로세스
struct SystemPanelView: View {
    var systemMonitor: SystemMonitor?

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("System")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if let monitor = systemMonitor {
                ScrollView {
                    VStack(spacing: 0) {
                        // CPU 코어 히트맵
                        if monitor.coreCount > 0 {
                            coreHeatmapSection(monitor: monitor)
                            Divider().padding(.horizontal, 12)
                        }

                        // GPU 섹션
                        gpuSection(monitor: monitor)
                        Divider().padding(.horizontal, 12)

                        // RAM 바
                        if monitor.memoryTotal > 0 {
                            memoryBarSection(monitor: monitor)
                            Divider().padding(.horizontal, 12)
                        }

                        // 디스크 섹션
                        if !monitor.disks.isEmpty {
                            diskSection(monitor: monitor)
                            Divider().padding(.horizontal, 12)
                        }

                        // 네트워크 버블 시각화
                        networkBubbleSection(monitor: monitor)
                        Divider().padding(.horizontal, 12)

                        // Top CPU 프로세스
                        topProcessSection(
                            title: "Top CPU",
                            systemImage: "cpu",
                            processes: Array(monitor.topProcessesByCPU.prefix(5)),
                            valueFormatter: { String(format: "%.1fs", $0.cpuPercent) },
                            valueColor: { ColorHelpers.cpuColor($0.cpuPercent) }
                        )

                        // Top Memory 프로세스
                        topProcessSection(
                            title: "Top Memory",
                            systemImage: "memorychip",
                            processes: Array(monitor.topProcessesByMemory.prefix(5)),
                            valueFormatter: { SessionFormatter.formatMB($0.memoryMB) },
                            valueColor: { ColorHelpers.memoryColor($0.memoryMB) }
                        )

                        // 리스닝 포트
                        if !monitor.listeningPorts.isEmpty {
                            listeningPortsSection(monitor: monitor)
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("System monitor not available")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - CPU Core Heatmap

    private func coreHeatmapSection(monitor: SystemMonitor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(verbatim: "\(monitor.coreCount) Cores")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%d%%", Int(monitor.cpuUsage * 100)))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            let columns = min(monitor.coreCount, 8)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: columns), spacing: 3) {
                ForEach(0..<monitor.perCoreUsage.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorHelpers.coreColor(usage: monitor.perCoreUsage[i]))
                        .frame(height: 14)
                        .help("Core \(i): \(Int(monitor.perCoreUsage[i] * 100))%")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - GPU Section

    private func gpuSection(monitor: SystemMonitor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "display")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(monitor.gpuName.isEmpty ? "GPU" : monitor.gpuName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%d%%", Int(monitor.gpuUtilization * 100)))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                let fillW = geo.size.width * monitor.gpuUtilization
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(ColorHelpers.coreColor(usage: monitor.gpuUtilization))
                        .frame(width: fillW)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .cornerRadius(3)
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Memory Bar

    private func memoryBarSection(monitor: SystemMonitor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // RAM
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("RAM")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(verbatim: "\(SessionFormatter.formatMB(monitor.memoryUsed)) / \(SessionFormatter.formatMB(monitor.memoryTotal))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    let total = max(Double(monitor.memoryTotal), 1)
                    let activeW = geo.size.width * Double(monitor.memoryActive) / total
                    let wiredW = geo.size.width * Double(monitor.memoryWired) / total
                    let compressedW = geo.size.width * Double(monitor.memoryCompressed) / total

                    HStack(spacing: 0) {
                        Rectangle().fill(Color.green).frame(width: activeW)
                            .help("Active: \(SessionFormatter.formatMB(monitor.memoryActive))")
                        Rectangle().fill(Color.blue).frame(width: wiredW)
                            .help("Wired: \(SessionFormatter.formatMB(monitor.memoryWired))")
                        Rectangle().fill(Color.orange).frame(width: compressedW)
                            .help("Compressed: \(SessionFormatter.formatMB(monitor.memoryCompressed))")
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .cornerRadius(3)
                }
                .frame(height: 8)

                HStack(spacing: 8) {
                    legendDot(color: .green, label: "Active")
                    legendDot(color: .blue, label: "Wired")
                    legendDot(color: .orange, label: "Compressed")
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            }

            // Swap
            if monitor.swapTotal > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Swap")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(verbatim: "\(SessionFormatter.formatMB(monitor.swapUsed)) / \(SessionFormatter.formatMB(monitor.swapTotal))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(monitor.swapUsed > 0 ? .orange : .secondary)
                    }

                    GeometryReader { geo in
                        let total = max(Double(monitor.swapTotal), 1)
                        let usedW = geo.size.width * Double(monitor.swapUsed) / total

                        HStack(spacing: 0) {
                            Rectangle().fill(ColorHelpers.swapColor(used: monitor.swapUsed, total: monitor.swapTotal))
                                .frame(width: usedW)
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                        .cornerRadius(3)
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Disk Section

    private func diskSection(monitor: SystemMonitor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Disks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            ForEach(monitor.disks, id: \.mountPoint) { disk in
                diskRow(disk: disk)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func diskRow(disk: DiskInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(disk.name)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%.1f / %.1f GB", disk.usedGB, disk.totalGB))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                let ratio = disk.totalGB > 0 ? min(disk.usedGB / disk.totalGB, 1.0) : 0
                let fillW = geo.size.width * ratio
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(ColorHelpers.diskColor(ratio: ratio))
                        .frame(width: fillW)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .cornerRadius(3)
            }
            .frame(height: 6)
        }
    }

    // MARK: - Network Bubble Visualization

    private func networkBubbleSection(monitor: SystemMonitor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "network")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Network")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let halfW = w / 2

                ZStack {
                    // 중앙 구분선
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1, height: h)
                        .position(x: halfW, y: h / 2)

                    // 수신 (왼쪽 — 초록)
                    let inBubbles = bubblePositions(
                        count: bubbleCount(bytes: monitor.networkBytesIn),
                        areaWidth: halfW - 4,
                        areaHeight: h,
                        offsetX: 0,
                        seed: 1
                    )
                    ForEach(inBubbles.indices, id: \.self) { i in
                        let b = inBubbles[i]
                        Circle()
                            .fill(Color.green.opacity(0.55))
                            .frame(width: b.size, height: b.size)
                            .position(x: b.x, y: b.y)
                    }

                    // 송신 (오른쪽 — 파랑)
                    let outBubbles = bubblePositions(
                        count: bubbleCount(bytes: monitor.networkBytesOut),
                        areaWidth: halfW - 4,
                        areaHeight: h,
                        offsetX: halfW + 4,
                        seed: 2
                    )
                    ForEach(outBubbles.indices, id: \.self) { i in
                        let b = outBubbles[i]
                        Circle()
                            .fill(Color.blue.opacity(0.55))
                            .frame(width: b.size, height: b.size)
                            .position(x: b.x, y: b.y)
                    }
                }
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .background(Color.secondary.opacity(0.05).cornerRadius(4))
            }
            .frame(height: 52)

            // 실제 bytes/sec 텍스트
            HStack {
                HStack(spacing: 3) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("↓ \(SessionFormatter.formatBytes(monitor.networkBytesIn))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 3) {
                    Text("↑ \(SessionFormatter.formatBytes(monitor.networkBytesOut))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    Circle().fill(Color.blue).frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// bytes/sec를 버블 개수 (0~10)로 변환한다
    private func bubbleCount(bytes: UInt64) -> Int {
        // 0 B/s = 0, 1 MB/s = 10개 (선형 스케일)
        let mbps = Double(bytes) / 1_048_576
        return min(Int(mbps * 10), 10)
    }

    private struct BubbleSpec {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
    }

    /// 결정론적 의사난수로 버블 위치를 계산한다 (seed로 in/out 구분)
    private func bubblePositions(
        count: Int,
        areaWidth: CGFloat,
        areaHeight: CGFloat,
        offsetX: CGFloat,
        seed: UInt64
    ) -> [BubbleSpec] {
        guard count > 0, areaWidth > 0, areaHeight > 0 else { return [] }
        var specs: [BubbleSpec] = []
        specs.reserveCapacity(count)
        // LCG 의사난수 — 고정 seed로 재생성 시 같은 위치 유지
        var rng = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let minSize: CGFloat = 6
        let maxSize: CGFloat = min(areaWidth, areaHeight) * 0.35

        for i in 0..<count {
            rng = rng &* 6_364_136_223_846_793_005 &+ UInt64(i + 1) &* 1_442_695_040_888_963_407
            let nx = CGFloat(rng & 0xFFFF) / 65535.0
            rng = rng &* 6_364_136_223_846_793_005 &+ 1
            let ny = CGFloat(rng & 0xFFFF) / 65535.0
            rng = rng &* 6_364_136_223_846_793_005 &+ 1
            let ns = CGFloat(rng & 0xFFFF) / 65535.0

            let size = minSize + ns * (maxSize - minSize)
            let half = size / 2
            let x = offsetX + half + nx * (areaWidth - size)
            let y = half + ny * (areaHeight - size)
            specs.append(BubbleSpec(x: x, y: y, size: size))
        }
        return specs
    }

    // MARK: - Top Processes

    private func topProcessSection(
        title: String,
        systemImage: String,
        processes: [ProcessStat],
        valueFormatter: @escaping (ProcessStat) -> String,
        valueColor: @escaping (ProcessStat) -> Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            ForEach(processes) { proc in
                HStack(spacing: 6) {
                    Text(proc.name)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(valueFormatter(proc))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(valueColor(proc))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            }

            if processes.isEmpty {
                Text("No data")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Listening Ports

    private func listeningPortsSection(monitor: SystemMonitor) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "network")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Listening Ports")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            ForEach(monitor.listeningPorts) { port in
                HStack(spacing: 6) {
                    Text(verbatim: ":\(port.port)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.blue)
                    Text(port.processName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }
}
