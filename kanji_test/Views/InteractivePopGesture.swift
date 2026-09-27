import SwiftUI
import UIKit

extension View {
    /// Возвращает системный свайп-назад (страница едет за пальцем) экранам
    /// стека со скрытым navigation bar: UIKit при скрытом баре его отключает.
    func interactivePopGesture(isEnabled: Bool) -> some View {
        background(InteractivePopGestureInstaller(isEnabled: isEnabled))
    }
}

private struct InteractivePopGestureInstaller: UIViewControllerRepresentable {
    let isEnabled: Bool

    func makeCoordinator() -> PopGestureDelegate { PopGestureDelegate() }

    func makeUIViewController(context: Context) -> ProbeViewController {
        ProbeViewController(popDelegate: context.coordinator)
    }

    func updateUIViewController(_ controller: ProbeViewController, context: Context) {
        context.coordinator.isEnabled = isEnabled
    }

    final class ProbeViewController: UIViewController {
        private let popDelegate: PopGestureDelegate

        init(popDelegate: PopGestureDelegate) {
            self.popDelegate = popDelegate
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            popDelegate.attach(to: navigationController)
        }
    }

    final class PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
        private weak var navigationController: UINavigationController?
        var isEnabled = true {
            didSet { navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = isEnabled }
        }

        func attach(to navigationController: UINavigationController?) {
            guard let navigationController else { return }
            self.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.delegate = self
            navigationController.interactiveContentPopGestureRecognizer?.isEnabled = isEnabled
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let navigationController else { return false }
            return navigationController.viewControllers.count > 1
        }
    }
}
