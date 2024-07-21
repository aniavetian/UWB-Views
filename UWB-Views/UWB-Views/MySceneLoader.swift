//
//  MySceneLoader.swift
//  ViewsAR
//
//  Created by Ani Avetian on 5/19/24.
//

import Foundation
import RealityKit


// This class provides a method to load the scene from the .reality file
class MySceneLoader {
    // Replace `MyScene` with the actual name of your .reality file without the extension
//    static func loadScene() -> RealityKit.AnchorEntity? {
//        do {
//            let realityScene = try InfoDot.loadScene()
//            return realityScene
//        } catch {
//            print("Error loading Reality file: \(error.localizedDescription)")
//            return nil
//        }
//    }
   
   func createRealityURL(filename: String,
                         fileExtension: String,
                         sceneName:String) -> URL? {
       // Create a URL that points to the specified Reality file.
       guard let realityFileURL = Bundle.main.url(forResource: filename,
                                                  withExtension: fileExtension) else {
           print("Error finding Reality file \(filename).\(fileExtension)")
           return nil
       }


       // Append the scene name to the URL to point to
       // a single scene within the file.
       let realityFileSceneURL = realityFileURL.appendingPathComponent(sceneName,
                                                                       isDirectory: false)
       return realityFileSceneURL
   }

}
