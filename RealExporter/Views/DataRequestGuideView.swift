import SwiftUI

struct DataRequestGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private static let gdprMessage = """
        Hello,

        I am exercising my right under Article 15 of the GDPR to request a copy of all personal data you hold about me.

        Please provide this data in a portable format (e.g., JSON/ZIP) within the 45-day legal timeframe.

        Thank you.
        """

    private static let steps = [
        "Open the **BeReal** app",
        "Tap your **Profile** (top right)",
        "Tap **Settings** (gear icon)",
        "Tap **Help**",
        "Tap **Contact Us**",
        "Tap **Report a Problem**",
        "Tap **Other**",
        "Tap **Still Need Help?**",
        "Tap **Select Topic**",
        "Select **\"I'd like to request a copy of my data\"**",
        "In the message box, paste the message below",
        "Tap **Send**",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("How to Get Your BeReal Data")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)

                    stepsSection

                    Divider()

                    messageSection

                    Divider()

                    expectSection
                }
                .padding(32)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 500, idealHeight: 600)
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Steps in the App", systemImage: "list.number")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .foregroundColor(.secondary)
                            .frame(width: 24, alignment: .trailing)
                            .monospacedDigit()

                        Text(markdownToAttributed(step))
                    }
                    .font(.body)
                }
            }
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Message to Send", systemImage: "doc.on.clipboard")
                .font(.headline)

            VStack(spacing: 0) {
                Text(Self.gdprMessage)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)

                Divider()

                HStack {
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.gdprMessage, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        Label(
                            copied ? "Copied!" : "Copy Message",
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .padding(12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.2))
            )
        }
    }

    private var expectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What to Expect", systemImage: "clock")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                bulletPoint("BeReal must respond within **45 days**")
                Text("You'll receive a ZIP file containing:")
                    .padding(.leading, 4)
                bulletPoint("Your photos in WebP format", indented: true)
                bulletPoint("A JSON file with all your data and metadata", indented: true)
            }
        }
    }

    private func bulletPoint(_ text: String, indented: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(markdownToAttributed(text))
        }
        .padding(.leading, indented ? 20 : 4)
    }

    private func markdownToAttributed(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }
}
