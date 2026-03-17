import AppKit

/// GhosttySurfaceView를 NSScrollView로 감싸는 컨테이너
/// Ghostty의 SurfaceScrollView 패턴을 따름
/// NSScrollView가 Metal 렌더링 레이어의 클리핑과 프레임 동기화를 보장
class SurfaceContainerView: NSView {
    private let scrollView: NSScrollView
    private let documentView: NSView
    let surfaceView: GhosttySurfaceView

    /// 윈도우 라이브 리사이즈 중인지 여부
    private var isLiveResizing = false

    /// 라이브 리사이즈 종료 감지용 옵저버
    nonisolated(unsafe) private var resizeObservers: [NSObjectProtocol] = []

    init(surfaceView: GhosttySurfaceView) {
        self.surfaceView = surfaceView

        // NSScrollView 설정 (Ghostty 패턴)
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.usesPredominantAxisScrolling = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.contentView.clipsToBounds = false

        // Document view: scrollView의 실제 컨텐츠
        documentView = NSView(frame: .zero)
        scrollView.documentView = documentView

        // SurfaceView를 document view의 자식으로 추가
        documentView.addSubview(surfaceView)

        super.init(frame: .zero)

        addSubview(scrollView)

        // 윈도우 라이브 리사이즈 시작/종료 감지
        resizeObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSWindow.willStartLiveResizeNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                self?.isLiveResizing = true
            }
        )
        resizeObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSWindow.didEndLiveResizeNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.isLiveResizing = false
                // 드래그 끝: 최종 크기로 PTY 리사이즈
                let size = self.scrollView.bounds.size
                if size.width > 0 && size.height > 0 {
                    self.surfaceView.sizeDidChange(size)
                }
            }
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    deinit {
        resizeObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsetsZero }

    override func layout() {
        super.layout()

        // 뷰 프레임은 항상 즉시 동기화 (Metal 렌더링이 뷰 크기를 따라감)
        scrollView.frame = bounds
        surfaceView.frame.size = scrollView.bounds.size
        documentView.frame.size = scrollView.bounds.size

        // 드래그 중이 아닐 때만 PTY 리사이즈 (프로그래밍 방식 리사이즈, 초기 배치 등)
        if !isLiveResizing {
            let size = scrollView.bounds.size
            if size.width > 0 && size.height > 0 {
                surfaceView.sizeDidChange(size)
            }
        }
    }
}
