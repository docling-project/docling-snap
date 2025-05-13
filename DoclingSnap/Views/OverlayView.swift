//
//  OverlayView.swift
//  HuggingSnap
//
//  Created by Cyril Zakka on 2/12/25.
//

import SwiftUI
import MarkdownUI

struct MessageView: View {
    
    var text: String = ""
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            VStack(spacing: 15) {
                ScrollView {
                    Markdown(text)
                        .padding(.vertical, 7)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                
                HStack(spacing:5) {
                    Label("SmolVLM", image: "huggy.fill")
                        .foregroundStyle(.yellow)
                        .fontWeight(.semibold)
                        .font(.caption)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text("Check important info for mistakes.")
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.caption)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            
        }
        .padding()
    }
}


#Preview {
    ContentView()
}

