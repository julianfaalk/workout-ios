import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var payload = WorkoutFriendsResponse(
        friendCode: "",
        inviteLink: "",
        friends: [],
        incomingRequests: [],
        outgoingRequests: []
    )
    @Published var leaderboard: [WorkoutLeaderboardEntry] = []
    @Published var inviteCodeInput = ""
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let api = WorkoutAPIService.shared
    private let localization = LocalizationService.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let friendsPayload = api.fetchFriends()
            async let board = api.fetchLeaderboard()
            payload = try await friendsPayload
            leaderboard = try await board
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendInviteRequest(using code: String? = nil) async {
        let targetCode = (code ?? inviteCodeInput).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !targetCode.isEmpty else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await api.sendFriendRequest(friendCode: targetCode)
            inviteCodeInput = ""
            successMessage = localization.localized("friends.request.sent")
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptRequest(id: String) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await api.acceptFriendRequest(requestID: id)
            successMessage = localization.localized("friends.request.accepted")
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(id: String) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await api.deleteFriend(friendID: id)
            successMessage = localization.localized("friends.friend.removed")
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
