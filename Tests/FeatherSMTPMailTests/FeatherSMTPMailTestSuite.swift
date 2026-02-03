//
//  FeatherSMTPMailTestSuite.swift
//  feather-smtp-mail
//
//  Created by Tibor Bodecs on 2023. 01. 16..
//

import NIO
import Logging
import Testing
import NIOSMTP
import FeatherMail
@testable import FeatherSMTPMail

@Suite
struct FeatherSMTPMailTestSuite {

    // MARK: - Environment configuration

    private let config = TestSMTPConfig.load()

    private func runClient(
        hostname: String? = nil,
        port: Int? = nil,
        username: String? = nil,
        password: String? = nil,
        _ closure: @escaping @Sendable (SMTPMailClient) async throws -> Void
    ) async throws {
        let signInMethod: SignInMethod
        if let username, let password {
            signInMethod = .credentials(username: username, password: password)
        }
        else {
            signInMethod =
                config.user.isEmpty
                ? .anonymous
                : .credentials(username: config.user, password: config.pass)
        }

        let config = Configuration(
            hostname: hostname ?? config.host,
            port: port ?? 587,
            signInMethod: signInMethod
        )

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { Task { await shutdownEventLoopGroup(eventLoopGroup) } }

        let client = SMTPMailClient(
            configuration: config,
            eventLoopGroup: eventLoopGroup
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await closure(client)
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private func shutdownEventLoopGroup(_ eventLoopGroup: EventLoopGroup) async
    {
        await withCheckedContinuation { continuation in
            eventLoopGroup.shutdownGracefully { _ in
                continuation.resume()
            }
        }
    }

    // MARK: - Tests

    @Test
    func sendPlainTextMail() async throws {
        try await runClient { client in

            let mail = Mail(
                from: .init(config.from),
                to: [.init(config.to)],
                subject: "SMTP plain text test",
                body: .plainText("Hello from Feather SMTP client.")
            )

            try await client.send(mail)
        }
    }

    @Test
    func sendHTMLMail() async throws {
        try await runClient { client in

            let mail = Mail(
                from: .init(config.from),
                to: [.init(config.to)],
                subject: "SMTP HTML test",
                body: .html("<p>Hello <strong>SMTP</strong></p>")
            )

            try await client.send(mail)
        }
    }

    @Test
    func sendMailWithAttachment() async throws {
        try await runClient { client in

            let data = Array("Hello attachment".utf8)

            let mail = Mail(
                from: .init(config.from),
                to: [.init(config.to)],
                subject: "SMTP Attachment Test",
                body: .plainText("This mail contains an attachment."),
                attachments: [
                    .init(
                        name: "test.txt",
                        contentType: "text/plain",
                        data: data
                    )
                ]
            )

            try await client.send(mail)
        }
    }

    @Test
    func invalidMailFailsBeforeSending() async {
        do {
            try await runClient { client in

                let mail = Mail(
                    from: .init(" "),
                    to: [.init(config.to)],
                    subject: "Invalid sender",
                    body: .plainText("This should not be sent.")
                )

                do {
                    try await client.send(mail)
                    Issue.record("Expected send to fail.")
                }
                catch {
                    if case let .validation(validationError) = error
                        as? MailError,
                        validationError == .invalidSender
                    {
                        #expect(true)
                    }
                    else {
                        Issue.record("Unexpected error: \(error)")
                    }
                }
            }
        }
        catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func badHostMapsToUnknownMailError() async {
        do {
            try await runClient(hostname: "invalid.smtp.local") { client in
                let mail = Mail(
                    from: .init(config.from),
                    to: [.init(config.to)],
                    subject: "Bad host",
                    body: .plainText("This should fail.")
                )

                do {
                    try await client.send(mail)
                    Issue.record("Expected send to fail.")
                }
                catch {
                    if case .unknown = error as? MailError {
                        #expect(true)
                    }
                    else {
                        Issue.record("Unexpected error: \(error)")
                    }
                }
            }
        }
        catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func badPortMapsToUnknownMailError() async {
        do {
            try await runClient(port: 1) { client in
                let mail = Mail(
                    from: .init(config.from),
                    to: [.init(config.to)],
                    subject: "Bad port",
                    body: .plainText("This should fail.")
                )

                do {
                    try await client.send(mail)
                    Issue.record("Expected send to fail.")
                }
                catch {
                    if case .unknown = error as? MailError {
                        #expect(true)
                    }
                    else {
                        Issue.record("Unexpected error: \(error)")
                    }
                }
            }
        }
        catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func badUserMapsToUnknownMailError() async {
        do {
            try await runClient(
                username: "invalid-user",
                password: config.pass
            ) { client in
                let mail = Mail(
                    from: .init(config.from),
                    to: [.init(config.to)],
                    subject: "Bad user",
                    body: .plainText("This should fail.")
                )

                do {
                    try await client.send(mail)
                    Issue.record("Expected send to fail.")
                }
                catch {
                    if case .custom = error as? MailError {
                        #expect(true)
                    }
                    else {
                        Issue.record("Unexpected error: \(error)")
                    }
                }
            }
        }
        catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func badPasswordMapsToUnknownMailError() async {
        do {
            try await runClient(
                username: config.user,
                password: "invalid-pass"
            ) { client in
                let mail = Mail(
                    from: .init(config.from),
                    to: [.init(config.to)],
                    subject: "Bad password",
                    body: .plainText("This should fail.")
                )

                do {
                    try await client.send(mail)
                    Issue.record("Expected send to fail.")
                }
                catch {
                    if case .custom = error as? MailError {
                        #expect(true)
                    }
                    else {
                        Issue.record("Unexpected error: \(error)")
                    }
                }
            }
        }
        catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

}
