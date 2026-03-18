import SwiftUI

struct TemplateListView: View {
    @StateObject private var viewModel = TemplateViewModel()
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showingAddTemplate = false
    @State private var showingPaywall = false
    @State private var selectedTemplate: WorkoutTemplate?

    private var customTemplateCount: Int {
        viewModel.templates.filter { !AppConfig.builtInTemplateNames.contains($0.name) }.count
    }

    private var canCreateCustomTemplate: Bool {
        storeManager.isPremium || customTemplateCount < AppConfig.maxFreeCustomTemplates
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.templates.isEmpty {
                    ContentUnavailableView(
                        "No Templates",
                        systemImage: "doc.text",
                        description: Text("Create workout templates to plan your sessions")
                    )
                } else {
                    List {
                        ForEach(viewModel.templates) { template in
                            NavigationLink(value: template) {
                                TemplateRowView(template: template)
                            }
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    let template = viewModel.templates[index]
                                    await viewModel.deleteTemplate(template)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Templates")
            .navigationDestination(for: WorkoutTemplate.self) { template in
                TemplateDetailView(templateId: template.id, viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if canCreateCustomTemplate {
                            showingAddTemplate = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTemplate) {
                TemplateFormView(viewModel: viewModel)
            }
            .refreshable {
                await viewModel.loadTemplates()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
                    .environmentObject(storeManager)
            }
        }
    }
}

struct TemplateRowView: View {
    let template: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.headline)

            Text("Created \(template.createdAt, style: .date)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TemplateListView()
}
