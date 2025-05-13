//
//  SettingsView.swift
//  HuggingSnap
//
//  Created by Cyril Zakka on 2/24/25.
//

import SwiftUI
import MessageUI

struct SettingsView: View {
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    
    // Support
    @State var result: Result<MFMailComposeResult, Error>? = nil
    @State var isShowingMailView = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Support") {
                    Button(action: {
                        guard let url = URL(string: "https://docling.io") else { return }
                                               openURL(url)
                    }, label: {
                        Label(title: {
                            Text("About Docling")
                                .foregroundStyle(.primary)
                        }, icon: {
                            Image(systemName: "link")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        })
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .imageScale(.medium)
                    })
                    .tint(.primary)
                    .accessibilityLabel(Text("Check Docling page on GitHub"))
                    .buttonStyle(.borderless)
                    .contentShape(Rectangle())
                    
                    Button(action: {
                        guard let url = URL(string: "https://huggingface.co/ds4sd/SmolDocling-256M-preview") else { return }
                        openURL(url)
                    }, label: {
                        Label(title: {
                            Text("About SmolDocling-256M")
                                .foregroundStyle(.primary)
                        }, icon: {
                            Image(systemName: "link")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        })
                        
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .imageScale(.medium)
                    })
                    .tint(.primary)
                    .accessibilityLabel(Text("Check SmolDocling page on huggingface"))
                    .buttonStyle(.borderless)
                    .contentShape(Rectangle())
                    
                    LabeledContent {
                        Text(Bundle.main.releaseVersionNumberPretty)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label(title: {
                            Text("DoclingSnap")
                        }, icon: {
                            Image("huggy.fill")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 15, height: 15)
                        })
                        .imageScale(.medium)
                    }
                    .accessibilityLabel(Text("DoclingSnap version \(Bundle.main.releaseVersionNumberPretty)"))
                }
                
                /*
                Button(action: {
                    isShowingMailView.toggle()
                }, label: {
                    Label(title: {
                        Text("Contact Us")
                            .foregroundStyle(.primary)
                    }, icon: {
                        Image(systemName: "envelope")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    })
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .imageScale(.medium)
                })
                .tint(.primary)
                .accessibilityLabel(Text("Press the button to send an email to Hugging Face support."))
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
                .sheet(isPresented: $isShowingMailView) {
                    MailView(
                        result: self.$result,
                        recipients: ["support@huggingface.co"],
                        subject: "HuggingSnap Feedback",
                        messageBody: "Please describe your issue below:\n\n\n\n\n" + UIDevice.getDeviceInfo(),
                        isHTML: false
                    )
                }
                */
                
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
