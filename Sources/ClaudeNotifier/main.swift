import Cocoa
import UserNotifications

// MARK: - CLI Arguments Parser

struct CLIArguments {
    var message: String?
    var title: String = "Terminal"
    var subtitle: String?
    var actions: [String] = []
    var closeLabel: String = "Close"
    var dropdownLabel: String?
    var timeout: TimeInterval?
    var sound: String?
    var json: Bool = false
    var reply: Bool = false
    var group: String?
    var remove: String?
    var list: String?
    var appIcon: String?
    var contentImage: String?

    static func parse() -> CLIArguments {
        var args = CLIArguments()
        let arguments = CommandLine.arguments
        var i = 1

        while i < arguments.count {
            let arg = arguments[i]

            switch arg {
            case "-message":
                i += 1
                if i < arguments.count { args.message = arguments[i] }
            case "-title":
                i += 1
                if i < arguments.count { args.title = arguments[i] }
            case "-subtitle":
                i += 1
                if i < arguments.count { args.subtitle = arguments[i] }
            case "-actions":
                i += 1
                if i < arguments.count {
                    args.actions = parseActions(arguments[i])
                }
            case "-closeLabel":
                i += 1
                if i < arguments.count { args.closeLabel = arguments[i] }
            case "-dropdownLabel":
                i += 1
                if i < arguments.count { args.dropdownLabel = arguments[i] }
            case "-timeout":
                i += 1
                if i < arguments.count { args.timeout = TimeInterval(arguments[i]) }
            case "-sound":
                i += 1
                if i < arguments.count { args.sound = arguments[i] }
            case "-json":
                args.json = true
            case "-reply":
                args.reply = true
            case "-group":
                i += 1
                if i < arguments.count { args.group = arguments[i] }
            case "-remove":
                i += 1
                if i < arguments.count { args.remove = arguments[i] }
            case "-list":
                i += 1
                if i < arguments.count { args.list = arguments[i] }
            case "-appIcon":
                i += 1
                if i < arguments.count { args.appIcon = arguments[i] }
            case "-contentImage":
                i += 1
                if i < arguments.count { args.contentImage = arguments[i] }
            case "-help", "-h":
                printUsage()
                exit(0)
            default:
                break
            }
            i += 1
        }

        // Read message from stdin if not provided
        if args.message == nil && !FileHandle.standardInput.isTerminal {
            if let data = try? FileHandle.standardInput.readToEnd(),
               let str = String(data: data, encoding: .utf8) {
                args.message = str.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return args
    }

    private static func parseActions(_ input: String) -> [String] {
        var actions: [String] = []
        var current = ""
        var inQuotes = false

        for char in input {
            if char == "\"" {
                inQuotes = !inQuotes
            } else if char == "," && !inQuotes {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    actions.append(trimmed)
                }
                current = ""
            } else {
                current.append(char)
            }
        }

        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            actions.append(trimmed)
        }

        return actions
    }
}

func printUsage() {
    let usage = """
    claude-notifier - Send macOS notifications with action buttons

    USAGE:
        claude-notifier -message MESSAGE [options]
        echo MESSAGE | claude-notifier [options]

    OPTIONS:
        -message VALUE      The message body of the notification
        -title VALUE        The title of the notification (default: Terminal)
        -subtitle VALUE     The subtitle of the notification
        -actions VAL1,VAL2  Actions to use (comma-separated, quote if spaces)
        -closeLabel VALUE   The label of the close button (default: Close)
        -dropdownLabel VAL  The label of the dropdown (for multiple actions)
        -timeout NUMBER     Auto-close after NUMBER seconds
        -sound NAME         Play sound (use 'default' for default sound)
        -json               Output result as JSON
        -reply              Show reply text field
        -group ID           Group notifications by ID
        -remove ID          Remove notifications with group ID (ALL for all)
        -list ID            List notifications with group ID
        -appIcon PATH       Custom app icon (file path or URL)
        -contentImage PATH  Content image (file path or URL)
        -help               Show this help

    OUTPUT:
        @TIMEOUT            Notification timed out
        @CLOSED             User clicked close button
        @CONTENTCLICKED     User clicked notification body
        @ACTIONCLICKED      User clicked default action
        <action>            The action button the user clicked
        <text>              User's reply text (with -reply)

    EXAMPLES:
        claude-notifier -message "Hello World"
        claude-notifier -message "Deploy?" -actions "Yes,No" -timeout 30
        claude-notifier -message "Allow?" -actions "Allow,Deny" -sound default
        echo "Piped message" | claude-notifier -sound default
    """
    print(usage)
}

extension FileHandle {
    var isTerminal: Bool {
        return isatty(fileDescriptor) != 0
    }
}

// MARK: - Output

enum NotificationResult {
    case timeout
    case closed
    case contentClicked
    case actionClicked(String)
    case replied(String)
    case dismissed

    var stringValue: String {
        switch self {
        case .timeout:
            return "@TIMEOUT"
        case .closed:
            return "@CLOSED"
        case .contentClicked:
            return "@CONTENTCLICKED"
        case .actionClicked(let action):
            return action
        case .replied(let text):
            return text
        case .dismissed:
            return "@CLOSED"
        }
    }

    func output(asJSON: Bool) {
        if asJSON {
            let json: [String: Any]
            switch self {
            case .timeout:
                json = ["activationType": "timeout", "activationValue": "@TIMEOUT"]
            case .closed:
                json = ["activationType": "closed", "activationValue": "@CLOSED"]
            case .contentClicked:
                json = ["activationType": "contentsClicked", "activationValue": "@CONTENTCLICKED"]
            case .actionClicked(let action):
                json = ["activationType": "actionClicked", "activationValue": action]
            case .replied(let text):
                json = ["activationType": "replied", "activationValue": text]
            case .dismissed:
                json = ["activationType": "closed", "activationValue": "@CLOSED"]
            }
            if let data = try? JSONSerialization.data(withJSONObject: json),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            print(stringValue)
        }
    }
}

// MARK: - Notification Manager

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let args: CLIArguments
    private var timeoutTimer: Timer?
    private let notificationIdentifier: String

    static let categoryIdentifier = "CLAUDE_NOTIFIER_CATEGORY"
    static let replyActionIdentifier = "REPLY_ACTION"
    static let closeActionIdentifier = "CLOSE_ACTION"

    init(args: CLIArguments) {
        self.args = args
        self.notificationIdentifier = args.group ?? UUID().uuidString
        super.init()
    }

    func run() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Handle remove
        if let removeId = args.remove {
            removeNotifications(id: removeId)
            return
        }

        // Handle list
        if let listId = args.list {
            listNotifications(id: listId)
            return
        }

        // Request authorization
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                fputs("Error requesting authorization: \(error.localizedDescription)\n", stderr)
                exit(1)
            }

            if !granted {
                fputs("Notification permission denied\n", stderr)
                exit(1)
            }

            self.registerCategories()
            self.sendNotification()
        }

        // Run the app
        NSApplication.shared.run()
    }

    private func registerCategories() {
        let center = UNUserNotificationCenter.current()

        var notificationActions: [UNNotificationAction] = []

        // Add custom actions
        for (index, actionTitle) in args.actions.enumerated() {
            let action = UNNotificationAction(
                identifier: "ACTION_\(index)",
                title: actionTitle,
                options: []  // No .foreground - handle in background
            )
            notificationActions.append(action)
        }

        let categoryOptions: UNNotificationCategoryOptions = []

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: notificationActions,
            intentIdentifiers: [],
            options: categoryOptions
        )

        center.setNotificationCategories([category])
    }

    private func sendNotification() {
        guard let message = args.message else {
            fputs("Error: -message is required\n", stderr)
            printUsage()
            exit(1)
        }

        let content = UNMutableNotificationContent()
        content.title = args.title
        content.body = message
        content.categoryIdentifier = Self.categoryIdentifier

        if let subtitle = args.subtitle {
            content.subtitle = subtitle
        }

        if let sound = args.sound {
            if sound == "default" {
                content.sound = .default
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            }
        }

        // Store actions in userInfo for later retrieval
        content.userInfo = ["actions": args.actions]

        // Create request
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error = error {
                fputs("Error sending notification: \(error.localizedDescription)\n", stderr)
                exit(1)
            }

            // Set up timeout if specified
            if let timeout = self.args.timeout {
                DispatchQueue.main.async {
                    self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                        self.handleResult(.timeout)
                    }
                }
            }
        }
    }

    private func removeNotifications(id: String) {
        let center = UNUserNotificationCenter.current()

        if id.uppercased() == "ALL" {
            center.removeAllDeliveredNotifications()
            center.removeAllPendingNotificationRequests()
        } else {
            center.removeDeliveredNotifications(withIdentifiers: [id])
            center.removePendingNotificationRequests(withIdentifiers: [id])
        }

        exit(0)
    }

    private func listNotifications(id: String) {
        let center = UNUserNotificationCenter.current()

        center.getDeliveredNotifications { notifications in
            let filtered = notifications.filter { notification in
                id.uppercased() == "ALL" || notification.request.identifier == id
            }

            let result = filtered.map { notification -> [String: Any] in
                return [
                    "identifier": notification.request.identifier,
                    "title": notification.request.content.title,
                    "body": notification.request.content.body,
                    "date": ISO8601DateFormatter().string(from: notification.date)
                ]
            }

            if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }

            exit(0)
        }

        // Keep running until async operation completes
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 5))
    }

    private func handleResult(_ result: NotificationResult) {
        timeoutTimer?.invalidate()
        result.output(asJSON: args.json)

        // Clean up the notification
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])

        exit(0)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped on the notification body
            handleResult(.contentClicked)

        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            handleResult(.dismissed)

        case Self.closeActionIdentifier:
            handleResult(.closed)

        default:
            // Check if it's one of our custom actions
            if actionIdentifier.hasPrefix("ACTION_") {
                let indexStr = actionIdentifier.replacingOccurrences(of: "ACTION_", with: "")
                if let index = Int(indexStr), index < args.actions.count {
                    handleResult(.actionClicked(args.actions[index]))
                } else {
                    handleResult(.actionClicked(actionIdentifier))
                }
            } else if let textResponse = response as? UNTextInputNotificationResponse {
                handleResult(.replied(textResponse.userText))
            } else {
                handleResult(.actionClicked(actionIdentifier))
            }
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}

// MARK: - Main

let args = CLIArguments.parse()
let manager = NotificationManager(args: args)
manager.run()
