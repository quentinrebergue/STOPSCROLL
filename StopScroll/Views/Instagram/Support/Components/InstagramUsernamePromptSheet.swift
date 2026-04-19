import SwiftUI

struct InstagramUsernamePromptSheet: View {
    @Binding var username: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Entrez votre pseudo Instagram pour ouvrir votre profil depuis la navbar native.")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                TextField("pseudo_instagram", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.08)))

                Spacer()
            }
            .padding(16)
            .background(Color(white: 0.08).ignoresSafeArea())
            .navigationTitle("Pseudo Instagram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Valider") { onConfirm() }
                        .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
