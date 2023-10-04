//
//  ModuleAViewController.swift
//  AudioLabSwift
//
//  Created by William Landin on 9/24/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

//This is our view controller for Module 1, this is where it will listen to frequencies, when the "stop"
// button is pressed it will display the 1st and second highest frequencies.

import UIKit

class ModuleAViewController: UIViewController {

    
    @IBOutlet weak var firstHzLabel: UILabel!
    //button to pause recording and make 2 other labels appear.
    @IBOutlet weak var secondHzLabel: UILabel!
    @IBOutlet weak var graphView: UIView!
    //This is the label gives the user instructions of how to use our screen
    @IBOutlet weak var module_1_desc_button: UILabel!
    
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.graphView)
    }()

    
    struct ModuleBAudioConstants {
        //This gives us a buffer size that is large enough for 3Hz frequency resolution 
        static let AUDIO_BUFFER_SIZE = 1024 * 32 
    }
    
    // Create AudioModel Object With Specified Buffer Size
    let audio = AudioModel(buffer_size: ModuleBAudioConstants.AUDIO_BUFFER_SIZE,lookback: 45)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        graph?.addGraph(withName: "fft",
            shouldNormalizeForFFT: true,
            numPointsInGraph: ModuleBAudioConstants.AUDIO_BUFFER_SIZE / 2)
        graph?.addGraph(withName: "time",
            numPointsInGraph: ModuleBAudioConstants.AUDIO_BUFFER_SIZE)
        
        graph?.addGraph(withName: "timeUnfrozen",
            numPointsInGraph: ModuleBAudioConstants.AUDIO_BUFFER_SIZE)
        audio.startMicrophoneProcessing(withFps: 20)
        
        audio.play()
        // Repeat FPS Times / Second Using Timer Class
        let withFpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] (withFpsTimer) in
            self?.runOnInterval()
        }
       
        //Timer.scheduledTimer(timeInterval: 1.0/20.0, target: self, selector: #selector(runOnInterval), userInfo: nil, repeats: true)
        
        let updateViewTimer = Timer.scheduledTimer(withTimeInterval: 1.0/20.0, repeats: true) { [weak self] (updateViewTimer) in
            self?.updateView()
        }
    }
    // Function that runs the same times as the audio manager to update the labels
    @objc func runOnInterval(){
//        print("Hello World")
        
        if audio.isLoudSound(cutoff: 1.0) {
            audio.calcLoudestSounds(windowSize: 3)
        }
        firstHzLabel.text = "First Loudest: \(audio.peak1Freq)"
        secondHzLabel.text = "Second Loudest: \(audio.peak2Freq)"
        
    }
    
    @objc func updateView() {
        self.graph?.updateGraph(
            data: self.audio.frozenFftData,
            forKey: "fft"
        )
        self.graph?.updateGraph(
            data: self.audio.frozenTimeData,
            forKey: "time"
        )
        self.graph?.updateGraph(
            data: self.audio.timeData,
            forKey: "timeUnfrozen"
        )
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    override func viewWillDisappear(_ animated: Bool) {
        audio.pause()
    }

}
