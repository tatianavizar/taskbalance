import HotwireNative
import UIKit

/// « confirm » (app/javascript/confirm_dialog.js): every data-turbo-confirm
/// as a native alert. Both buttons have the same style: refusing weighs as
/// much as accepting (decision 2026-11-08 on manipulative patterns).
/// Data: { message, confirmLabel, cancelLabel }. Reply: { confirmed }.
final class ConfirmComponent: BridgeComponent {
    override class var name: String { "confirm" }

    private struct Request: Decodable {
        let message: String
        let confirmLabel: String?
        let cancelLabel: String?
    }

    private struct Answer: Encodable {
        let confirmed: Bool
    }

    override func onReceive(message: Message) {
        guard message.event == "show", let request: Request = message.data() else { return }
        let event = message.event

        let alert = UIAlertController(title: nil, message: request.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: request.cancelLabel ?? "Annuler", style: .default) { [weak self] _ in
            self?.answer(event, with: Answer(confirmed: false))
        })
        alert.addAction(UIAlertAction(title: request.confirmLabel ?? "Confirmer", style: .default) { [weak self] _ in
            self?.answer(event, with: Answer(confirmed: true))
        })
        UIApplication.shared.topViewController?.present(alert, animated: true)
    }
}

/// « overflow-menu » (E6, app/javascript/controllers/bridge/overflow_menu_controller.js):
/// the « ⋯ » of a row as an action sheet.
/// Data: { title, items: [{ title, index, destructive }] }. Reply: { selectedIndex }.
final class OverflowMenuComponent: BridgeComponent {
    override class var name: String { "overflow-menu" }

    private struct Item: Decodable {
        let title: String
        let index: Int
        let destructive: Bool?
    }

    private struct Request: Decodable {
        let title: String?
        let items: [Item]
    }

    private struct Answer: Encodable {
        let selectedIndex: Int
    }

    override func onReceive(message: Message) {
        guard message.event == "show", let request: Request = message.data(),
              let presenter = UIApplication.shared.topViewController else { return }
        let event = message.event

        let sheet = UIAlertController(title: request.title, message: nil, preferredStyle: .actionSheet)
        for item in request.items {
            let style: UIAlertAction.Style = item.destructive == true ? .destructive : .default
            sheet.addAction(UIAlertAction(title: item.title, style: style) { [weak self] _ in
                self?.answer(event, with: Answer(selectedIndex: item.index))
            })
        }
        sheet.addAction(UIAlertAction(title: "Annuler", style: .cancel))
        // iPad: an action sheet needs an anchor.
        sheet.popoverPresentationController?.sourceView = presenter.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
        presenter.present(sheet, animated: true)
    }
}

/// « date-picker » (D10, F6): every `as: :date` field (FiftyFormBuilder).
/// Data: { value, min, max } as "YYYY-MM-DD" (may be empty). Reply: { value }
/// on « OK »; nothing when cancelled.
final class DatePickerComponent: BridgeComponent {
    override class var name: String { "date-picker" }

    private struct Request: Decodable {
        let value: String?
        let min: String?
        let max: String?
    }

    private struct Answer: Encodable {
        let value: String
    }

    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    override func onReceive(message: Message) {
        guard message.event == "show", let request: Request = message.data() else { return }
        let event = message.event
        let parse: (String?) -> Date? = { text in
            guard let text, !text.isEmpty else { return nil }
            return Self.formatter.date(from: text)
        }

        let sheet = DatePickerSheet(
            date: parse(request.value) ?? Date(),
            minimum: parse(request.min),
            maximum: parse(request.max)
        ) { [weak self] picked in
            self?.answer(event, with: Answer(value: Self.formatter.string(from: picked)))
        }
        UIApplication.shared.topViewController?.present(UINavigationController(rootViewController: sheet), animated: true)
    }
}

/// A calendar in a half-height sheet, with « Annuler » and « OK ».
final class DatePickerSheet: UIViewController {
    private let picker = UIDatePicker()
    private let onPick: (Date) -> Void

    init(date: Date, minimum: Date?, maximum: Date?, onPick: @escaping (Date) -> Void) {
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.locale = Locale(identifier: "fr_FR")
        picker.minimumDate = minimum
        picker.maximumDate = maximum
        picker.date = date
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        picker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            picker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Annuler", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "OK", style: .done, target: self, action: #selector(done))
        navigationController?.sheetPresentationController?.detents = [.medium(), .large()]
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    @objc private func done() {
        let date = picker.date
        dismiss(animated: true) { self.onPick(date) }
    }
}
