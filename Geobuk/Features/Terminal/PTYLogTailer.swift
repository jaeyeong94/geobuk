import Foundation

/// 로그 파일을 tail하여 새로운 데이터를 스트리밍
/// DispatchSource로 파일 변경 감지 (polling 대신 커널 이벤트 사용)
actor PTYLogTailer {
    let filePath: String
    private var fileHandle: FileHandle?
    private var source: (any DispatchSourceFileSystemObject)?
    private var lastOffset: UInt64 = 0
    private(set) var isTailing: Bool = false

    init(filePath: String) {
        self.filePath = filePath
    }

    /// tail 시작 -- 새 데이터가 추가될 때마다 콜백 호출
    func startTailing(onData: @escaping @Sendable (Data) -> Void) {
        guard !isTailing else { return }

        guard FileManager.default.fileExists(atPath: filePath) else {
            // 파일이 없으면 tailing 시작하지 않음
            return
        }

        guard let handle = FileHandle(forReadingAtPath: filePath) else {
            return
        }

        self.fileHandle = handle

        // 현재 파일 끝으로 이동 (기존 데이터 건너뜀)
        handle.seekToEndOfFile()
        lastOffset = handle.offsetInFile

        let fd = handle.fileDescriptor
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: DispatchQueue.global(qos: .utility)
        )

        dispatchSource.setEventHandler { [weak self] in
            guard let self else { return }
            // actor 메서드를 비동기로 호출
            Task {
                await self.readNewData(onData: onData)
            }
        }

        dispatchSource.setCancelHandler { [weak handle] in
            try? handle?.close()
        }

        self.source = dispatchSource
        self.isTailing = true
        dispatchSource.resume()
    }

    /// tail 중지
    func stopTailing() {
        guard isTailing else {
            // 시작 전이라도 리소스 정리
            cleanupResources()
            return
        }

        isTailing = false
        source?.cancel()
        source = nil
        fileHandle = nil
    }

    // MARK: - Private

    /// 새로 추가된 데이터를 읽어서 콜백에 전달
    private func readNewData(onData: @escaping @Sendable (Data) -> Void) {
        guard let handle = fileHandle, isTailing else { return }

        handle.seek(toFileOffset: lastOffset)
        let data = handle.readDataToEndOfFile()

        if !data.isEmpty {
            lastOffset = handle.offsetInFile
            onData(data)
        }
    }

    /// 리소스 정리 (stopTailing 이전에도 호출 가능)
    private func cleanupResources() {
        source?.cancel()
        source = nil
        fileHandle = nil
        isTailing = false
    }
}
