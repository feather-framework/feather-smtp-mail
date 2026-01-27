//
//  SMTPClient.swift
//  feather-mail-driver-smtp
//
//  Created by gerp83 on 2026. 01. 17.
//

import Foundation
import NIO
import FeatherMail
import Logging
import NIOSMTP

/// Low-level SMTP client wrapper used by the driver.
public struct SMTPClient: Sendable {

    private let eventLoopGroup: EventLoopGroup
    private let smtp: NIOSMTP
    private let logger: Logger
    private let rawEncoder = RawMailEncoder()

    init(
        configuration: Configuration,
        logger: Logger
    ) {
        self.logger = logger
        self.eventLoopGroup = MultiThreadedEventLoopGroup(
            numberOfThreads: System.coreCount
        )

        self.smtp = NIOSMTP(
            eventLoopGroup: eventLoopGroup,
            configuration: configuration,
            logger: logger
        )
    }

    func send(_ mail: Mail) async throws {
        let raw = try rawEncoder.encode(
            mail,
            dateHeader: formatDateHeader(),
            messageID: createMessageID(for: mail)
        )
        let recipients = (mail.to + mail.cc + mail.bcc).map(\.email)
        let envelope = try SMTPEnvelope(
            from: mail.from.email,
            recipients: recipients,
            data: raw
        )
        try await smtp.send(envelope)
    }

    func shutdown() async throws {
        try await eventLoopGroup.shutdownGracefully()
    }

    private func formatDateHeader() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return dateFormatter.string(from: Date())
    }

    private func createMessageID(for mail: Mail) -> String {
        let time = Date().timeIntervalSince1970
        return "<\(time)\(mail.from.email.drop { $0 != "@" })>"
    }
}
