//
//  PhotoView.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-16.
//

import SwiftUI
import AVFoundation

import SwiftUI
import AVFoundation

struct PhotoView: View {
	@StateObject private var viewModel = PhotoViewModel()
	@State private var isShowingCamera = false
	@Environment(\.presentationMode) var presentationMode
	
	var body: some View {
		ZStack {
			BonsaiTheme.backgroundGradient
				.ignoresSafeArea()
			
			VStack(spacing: 25) {
				// Header
				Text("Capture Your Bonsai")
					.font(BonsaiTheme.titleFont)
					.foregroundColor(BonsaiTheme.primaryGreen)
				
				// Photo frame
				ZStack {
					RoundedRectangle(cornerRadius: 20)
						.fill(BonsaiTheme.sandBeige)
						.frame(width: 320, height: 320)
						.shadow(color: BonsaiTheme.earthBrown.opacity(0.3), radius: 10)
					
					RoundedRectangle(cornerRadius: 16)
						.stroke(BonsaiTheme.earthBrown, lineWidth: 3)
						.frame(width: 300, height: 300)
					
					if let image = viewModel.capturedImage {
						Image(uiImage: image)
							.resizable()
							.scaledToFill()
							.frame(width: 300, height: 300)
							.cornerRadius(16)
							.clipped()
					} else {
						VStack(spacing: 20) {
							Image(systemName: "camera.viewfinder")
								.resizable()
								.scaledToFit()
								.frame(width: 80, height: 80)
								.foregroundColor(BonsaiTheme.primaryGreen.opacity(0.7))
							
							Text("Position your bonsai in the frame")
								.font(BonsaiTheme.bodyFont)
								.foregroundColor(BonsaiTheme.earthBrown)
								.multilineTextAlignment(.center)
								.padding(.horizontal)
						}
					}
				}
				.padding(.vertical, 20)
				
				Spacer()
				
				// Camera button
				Button(action: {
					isShowingCamera = true
				}) {
					ZStack {
						Circle()
							.fill(BonsaiTheme.primaryGreen)
							.frame(width: 70, height: 70)
							.shadow(radius: 5)
						
						Image(systemName: "camera.fill")
							.font(.system(size: 30))
							.foregroundColor(.white)
					}
				}
				.padding(.bottom, 20)
				
				// Instructions
				Text("Make sure your bonsai is well-lit and clearly visible")
					.font(BonsaiTheme.bodyFont)
					.foregroundColor(BonsaiTheme.earthBrown)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 40)
					.padding(.bottom, 20)
				
				// Navigation link to Results
				NavigationLink(
					destination: ResultView(viewModel: ResultViewModel(waterLevel: viewModel.waterLevel ?? WaterLevel(percentage: 0))),
					isActive: $viewModel.navigateToResult
				) {
					EmptyView()
				}
			}
			.padding()
		}
		.navigationBarBackButtonHidden(true)
		.navigationBarItems(leading:
			Button(action: {
				presentationMode.wrappedValue.dismiss()
			}) {
				HStack {
					Image(systemName: "chevron.left")
					Text("Back")
				}
				.foregroundColor(BonsaiTheme.primaryGreen)
			}
		)
		.sheet(isPresented: $isShowingCamera) {
			CameraView(image: $viewModel.capturedImage, isShown: $isShowingCamera, processImage: viewModel.processImage)
		}
	}
}

// A simple camera view that will be presented as a sheet
struct CameraView: UIViewControllerRepresentable {
	@Binding var image: UIImage?
	@Binding var isShown: Bool
	var processImage: () -> Void
	
	func makeUIViewController(context: Context) -> UIImagePickerController {
		let picker = UIImagePickerController()
		picker.delegate = context.coordinator
		picker.sourceType = .camera
		return picker
	}
	
	func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
		let parent: CameraView
		
		init(_ parent: CameraView) {
			self.parent = parent
		}
		
		func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
			if let image = info[.originalImage] as? UIImage {
				parent.image = image
				parent.processImage()
			}
			parent.isShown = false
		}
		
		func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
			parent.isShown = false
		}
	}
}

#Preview {
	PhotoView()
}
