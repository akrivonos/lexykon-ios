import Foundation
import DictCore

public enum ContributionsService {
    /// Submits an error flag: authenticated contributors use `POST /contributions`; others use `POST /contributions/guest`.
    public static func submitErrorFlag(
        apiClient: DictAPIClient,
        targetId: String,
        description: String,
        guestEmail: String?,
        useAuthenticatedContributorPath: Bool
    ) async throws {
        let payload = FlagErrorPayload(description: description)
        if useAuthenticatedContributorPath {
            let body = ContributionSubmitBody(targetId: targetId, payload: payload)
            struct Envelope: Decodable {
                struct Inner: Decodable { let id: String? }
                let data: Inner?
            }
            _ = try await apiClient.request(
                path: "contributions",
                method: .post,
                body: body,
                requiresAuth: true
            ) as Envelope
        } else {
            let body = GuestContributionBody(
                targetId: targetId,
                payload: payload,
                guestEmail: guestEmail,
                captchaToken: nil
            )
            struct Envelope: Decodable {
                struct Inner: Decodable { let id: String? }
                let data: Inner?
            }
            _ = try await apiClient.request(
                path: "contributions/guest",
                method: .post,
                body: body,
                requiresAuth: false
            ) as Envelope
        }
    }

    public static func fetchMine(apiClient: DictAPIClient, limit: Int = 50, offset: Int = 0) async throws -> ContributionsMineResponse {
        try await apiClient.request(
            path: "contributions/mine",
            method: .get,
            queryItems: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)"),
            ],
            requiresAuth: true
        )
    }

    public static func fetchStats(apiClient: DictAPIClient) async throws -> ContributionStats {
        try await apiClient.request(path: "contributions/stats", method: .get, requiresAuth: true)
    }

    public static func withdraw(apiClient: DictAPIClient, contributionId: String) async throws {
        struct Envelope: Decodable { let data: WithdrawOK? }
        struct WithdrawOK: Decodable { let ok: Bool? }
        _ = try await apiClient.request(
            path: "contributions/\(contributionId)/withdraw",
            method: .patch,
            requiresAuth: true
        ) as Envelope
    }
}
