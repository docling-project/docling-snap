//
//  InputView.swift
//  HuggingSnap
//
//  Created by Cyril Zakka on 2/18/25.
//

import SwiftUI

struct InputView: View {

    @Environment(VLMEvaluator.self) private var llm
    @StateObject private var audioRecorder: SpeechRecognizer = SpeechRecognizer()
    @FocusState private var promptInFocus: Bool
    @Binding var isTextMode: Bool
    @Binding var isAudioMode: Bool
    @Binding var textFieldText: String
    
    var onSubmitAction: (String) -> Void = { _ in }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            Group {
                if !isAudioMode {
                    VStack {
                        TextField("", text: $textFieldText, prompt: Text("Ask anything...").foregroundColor(.secondary), axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(12)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .focused($promptInFocus)
                        
                        HStack {
                            Spacer()
                            Button {
                                isAudioMode = true
                                
                            } label: {
                                Image(systemName: "mic")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .fontWeight(.regular)
                            }
                            .tint(.white)
                            
                            Button {
                                if !llm.running {
                                    if !textFieldText.isEmpty {
                                        onSubmitAction(textFieldText)
                                    }
                                }
                                promptInFocus = false
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(.black, .primary)
                                    .fontWeight(.regular)
                                
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 5)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 12)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                            self.promptInFocus = true
                        }
                    }
                } else {
                    DictationInputToolbar(toggleDictationMode: $isAudioMode, inputText: $textFieldText)
                        .environmentObject(audioRecorder)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        .padding(.horizontal, 12)
                }
            }
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .fill(.ultraThickMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous).stroke(.gray.opacity(0.5), style: StrokeStyle(lineWidth: 0.5)))
                    Color.black.opacity(0.3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                .edgesIgnoringSafeArea(.bottom)
            }
            .fixedSize(horizontal: false, vertical: true)
            
            // Cancel button
            if !isAudioMode {
                Button {
                    textFieldText = ""
                    isTextMode = false
                } label: {
                    Image(systemName: "xmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 10, height: 10)
                        .fontWeight(.bold)
                        
                        .background {
                           Circle()
                                .fill(.ultraThickMaterial)
                                .frame(width: 35, height: 35)
                                .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous).stroke(.gray.opacity(0.5), style: StrokeStyle(lineWidth: 0.5)))
                            Color.black.opacity(0.3)
                                .clipShape(.circle)
                        }
                        
                        .padding(.bottom, 20)
                        .fontWeight(.regular)
                        .foregroundStyle(.primary, .quaternary)
                        .contentShape(Rectangle())
                }
                .contentShape(Rectangle())
                .tint(.primary)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 5)
    }
    
}

struct DictationInputToolbar: View {
    
    @EnvironmentObject var audioRecorder: SpeechRecognizer
    @Environment(\.colorScheme) var colorScheme
    @Binding var toggleDictationMode: Bool
    
    @Binding var inputText: String
    
    let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    var body: some View {
        HStack {
            Button {
                audioRecorder.stopTranscribing()
                toggleDictationMode.toggle()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                    .frame(width: 30, height: 30)
                    .fontWeight(.regular)
            }
            .foregroundStyle(.primary, .tertiary)
            .padding(.trailing, 5)
            .buttonStyle(.plain)
            Spacer()
            
            AudioWaveformView(isDictationMode: toggleDictationMode, samples: audioRecorder.audioLevels)
                .frame(height: 30)
                
            
            Text(timeFormatter.string(from: audioRecorder.transcriptionTime) ?? "0:00")
                .foregroundStyle(.primary)
                .fontWeight(.semibold)
                .contentTransition(.numericText())
                .font(.system(.footnote, design: .rounded))
            
            Button {
                audioRecorder.stopTranscribing()
                inputText += audioRecorder.transcript
                audioRecorder.resetTranscript()
                toggleDictationMode.toggle()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundStyle((colorScheme == .dark ? .black:.white), .primary)
                
            }
            .buttonStyle(.plain)
            .padding(.leading, 5)
            
            .onAppear {
                audioRecorder.startTranscribing()
            }
        }
    }
}

struct AudioWaveformView: View {
    var isDictationMode: Bool
    var samples: [Float]
    let maxHeight: CGFloat = 30
    let minHeight: CGFloat = 1
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 3) {
                    ForEach(samples.indices, id: \.self) { index in
                        let sample = samples[index]
                        Capsule()
                            .id(index)
                            .foregroundStyle(audioCapsuleColor(for: sample))
                            .frame(width: 2, height: audioCapsuleHeight(for: sample))
                            .animation(.smooth, value: sample)
                    }
                }
                .animation(.smooth, value: samples.count)
            }
            .onAppear {
                proxy.scrollTo(samples.count - 1, anchor: .trailing)
            }
            .onChange(of: samples.count) {
                withAnimation(.smooth){
                    proxy.scrollTo(samples.count - 1, anchor: .trailing)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
    }
    
    func audioCapsuleColor(for sample: Float) -> HierarchicalShapeStyle {
        if sample >= 0 {
            return .primary
        }
        return .quinary
    }
    
    func audioCapsuleHeight(for sample: Float) -> CGFloat {
        if sample >= 0 {
            // Scale the height between minHeight and maxHeight based on the sample value
            let scaledHeight = minHeight + (maxHeight - minHeight) * CGFloat(sample)
            return min(maxHeight, max(minHeight, scaledHeight))
        } else {
            return minHeight
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
