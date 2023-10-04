//
//  ViewController.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

//Imports UIKit and Metal 
import UIKit
import Metal





class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad() //Calls the UIViewController viewDidLoad() method 
        
//        if let graph = self.graph{
//            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
//
//            // add in graphs for display
//            // note that we need to normalize the scale of this graph
//            // becasue the fft is returned in dB which has very large negative values and some large positive values
//            graph.addGraph(withName: "fft",
//                            shouldNormalizeForFFT: true,
//                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
//
//            graph.addGraph(withName: "time",
//                numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
//
//            graph.makeGrids() // add grids to graph
//        }
//
//        // start up the audio model here, querying microphone
////        audio.startMicrophoneProcessing(withFps: 20) // preferred number of FFT calculations per second
//        audio.startFileProcessing(withFps: 20)
//        audio.play()
//
//        // run the loop for updating the graph peridocially
//        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
//            self.updateGraph()
//        }
       
    }
    
    // periodically, update the graph with refreshed FFT Data
//    func updateGraph(){
//
//        if let graph = self.graph{
//            graph.updateGraph(
//                data: self.audio.fftData,
//                forKey: "fft"
//            )
//
//            graph.updateGraph(
//                data: self.audio.timeData,
//                forKey: "time"
//            )
//        }
//
//    }
//
//    override func viewWillDisappear(_ animated: Bool) {
//        audio.pause()
//    }
//    override func viewWillAppear(_ animated: Bool) {
//        audio.play()
//    }
    
    

}

