//
//  ContentView.swift
//  ViewsAR
//
//  Created by ME on 4/5/24.
//

import SwiftUI
import RealityKit
import UIKit
import Combine
import GoogleGenerativeAI
import ARKit

let GOOGLE_API_KEY = ""
let GEMINI_API_KEY = ""

struct ContentView_Previews: PreviewProvider {
   static var previews: some View {
      ContentView()
   }
}

/*
 Content View showing all the features on the application
 */
struct ContentView: View {
   // Facts string to be updated with Gemini values
   @State private var facts: [String] = []
   // Color of AR text
   let textColor = Color.blue
   
   var body: some View {
      VStack {
         ARViewContainer(facts: $facts, textColor: textColor)
         HStack {
            CapturePhotoButton(facts: $facts)
            Spacer()
         }
      }.edgesIgnoringSafeArea(.all)
   }
}


/*
 Contains main logic to capture photos and send for detection and to
 interact with Gemini ML Model. Functions inside do all processing and cleaning
 work for the API interactions.
 */
struct CapturePhotoButton: View {
   // Facts object to update
   @Binding var facts: [String]
   
   // Button to capture photo
   var body: some View {
      Spacer()
      Button(action: {
         self.capturePhoto()
      }) {
         Text("Take Photo")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
      }
   }
   
   // Captures photo of AR view to send to landmark API
   func capturePhoto() {
      let window = UIApplication.shared.windows.first!
      
      UIGraphicsBeginImageContextWithOptions(window.frame.size, false, UIScreen.main.scale)
      window.drawHierarchy(in: window.frame, afterScreenUpdates: true)
      
      guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
         print("ERROR: FAILED TO CAPTURE IMAGE")
         return
      }
      
      UIGraphicsEndImageContext()
      
      if let imageData = image.jpegData(compressionQuality: 0.8) {
         detectLandmarks(image: imageData)
      }
      
      print("INFO: CAPTURED PHOTO!")
   }
   
   // Detect the landmark
   func detectLandmarks(image: Data) {
      let url = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=" + GOOGLE_API_KEY)!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      
      let jsonRequestBody: [String: Any] = [
         "requests": [
            [
               "image": [
                  "content": image.base64EncodedString()
               ],
               "features": [
                  [
                     "type": "LANDMARK_DETECTION"
                  ]
               ]
            ]
         ]
      ]
      
      guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonRequestBody) else {
         print("ERROR: FAILED TO CONVERT JSON TO DATA")
         return
      }
      
      request.httpBody = jsonData
      
      let task = URLSession.shared.dataTask(with: request) { data, response, error in
         if let error = error {
            print("ERROR: \(error)")
            return
         }
         
         guard let data = data else {
            print("ERROR: NO DATA")
            return
         }
         
         guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            print("ERROR: FAILED TO PARSE")
            return
         }
         
         // Debugging purposes
         //print("RESPONSE JSON: \(json)")
         
         // Grab landmakr information from response
         let responses = json["responses"] as? [[String: Any]]
         let firstResponse = responses?.first
         let landmarkAnnotations = firstResponse?["landmarkAnnotations"] as? [[String: Any]]
         let firstLandmark = landmarkAnnotations?.first
         let description = firstLandmark?["description"] as? String
         
         // Interact with gemini with the landmark description
         if let description = description {
            DispatchQueue.main.async {
               Task {
                  await interactWithGemini(landmark: description)
               }
            }
         }
      }
      task.resume()
   }
   
   // Create and call Gemini model for a fact about landmark.
   func interactWithGemini(landmark: String) async {
      let model = GenerativeModel(name: "gemini-1.5-flash", apiKey: GEMINI_API_KEY)
      let prompt = "Please show me the landmark name, put a : after the name with a fact about the landmark " + landmark
      let response = try? await model.generateContent(prompt)
      
      // Debugging purposes
      //print(response)
      
      // Insert into facts array
      if let text = response?.text {
         let factsArray = text.split(separator: "\n").map { String($0) }
         DispatchQueue.main.async {
            self.facts = factsArray
         }
      }
   }
}



/*
 Struct contains all AR functionality
 */
struct ARViewContainer: UIViewRepresentable {
   // Vars read in
   @Binding var facts: [String]
   var textColor: Color
   
   // Create the inital AR view to display to user
   func makeUIView(context: Context) -> ARView {
      // Create AR View
      let arView = ARView(frame: .zero)
      
      // Create AR config
      let config = ARWorldTrackingConfiguration()
      config.planeDetection = [.horizontal, .vertical]
      arView.session.run(config)
      
      return arView
   }
   
   // Clears the UI view and preps for AR text to show up
   func updateUIView(_ uiView: ARView, context: Context) {
      clearFact(uiView)
      for (index, fact) in facts.enumerated() {
         let textEntity = createARFact(text: fact, color: textColor)
         let position = SIMD3<Float>(0, Float(index) * 0.1, -0.5)
         textEntity.position = position
         uiView.scene.anchors.append(textEntity as! HasAnchoring)
      }
      
   }
   
   func createARFact(text: String, color: Color) -> Entity {
      // Generate AR text
      let mesh = MeshResource.generateText(
         text,
         extrusionDepth: 0.02,
         font: .boldSystemFont(ofSize: 0.1),
         containerFrame: .zero,
         alignment: .center,
         lineBreakMode: .byWordWrapping
      )
      
      // Convert SwiftUI.Color to RealityKit Material Color
      let materialColor = Color(color)
      let material = SimpleMaterial(color: .init(materialColor), isMetallic: false)
      
      // Create and anchor entity on AR plane
      let modelEntity = ModelEntity(mesh: mesh, materials: [material])
      let anchorEntity = AnchorEntity(plane: .horizontal)
      anchorEntity.addChild(modelEntity)
      return anchorEntity
   }
   
   // Clear all AR facts
   func clearFact(_ arView: ARView) {
      arView.scene.anchors.removeAll()
   }
}
