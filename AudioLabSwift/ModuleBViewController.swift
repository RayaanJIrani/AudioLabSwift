//
//  ModuleBViewController.swift
//  AudioLabSwift
//
//  Created by William Landin on 9/25/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//
//  Lab Two: Audio Filtering, FFT, Doppler Shifts
//  Trevor Dohm, Will Landin, Ray Irani, Alex Shockley
//

// Import Statements
import UIKit

// Module B View Controller - Main Runner For View
class ModuleBViewController: UIViewController {
    
    // Outlets Defined On Storyboard - Hopefully Self-Explanatory!
    @IBOutlet weak var gesture_label: UILabel!
    @IBOutlet weak var decibel_label: UILabel!
    @IBOutlet weak var tone_slider_label: UILabel!
    @IBOutlet weak var tone_slider: UISlider!
    @IBOutlet weak var graphView: UIView!
    
    // Action When Tone Slider Value Changed
    @IBAction func ToneSliderValueChanged(_ sender: UISlider) {
        //Updates the audio tone frequency based of the slider 
        audio.setToneFrequency(sender.value) 
        
        // Update Slider Label Text With Current Slider Value
        tone_slider_label.text = String(format: "Tone Slider: %.2f kHz", sender.value / 1000.0)
    }
    
    // Create AudioConstants For Module B
    // (Structure With Any Constants Necessary To Run AudioModel)
    struct ModuleBAudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }
    
    // Create AudioModel Object With Specified Buffer Size
    let audio = AudioModel(buffer_size: ModuleBAudioConstants.AUDIO_BUFFER_SIZE)
    
    // Instantiate Timer Object
    var updateViewTimer: Timer?
    
    // Lazy Instantiation For Graph
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.graphView)
    }()
    
    // Runs When View Loads (With Super Method)
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add Graphs For Display 

        //This creates the fft graph which displays the fast Fourier transform of the sound
        graph?.addGraph(withName: "fft",
            shouldNormalizeForFFT: true, 
            numPointsInGraph: ModuleBAudioConstants.AUDIO_BUFFER_SIZE / 2) 

        //Creates the raw audio graph 
        graph?.addGraph(withName: "time",
            numPointsInGraph: ModuleBAudioConstants.AUDIO_BUFFER_SIZE)
        
        // Querying Microphone, Speaker From AudioModel With Preferred
        // Calculations (Gestures, FFT, Doppler Shifts) Per Second
        audio.startDualProcessing(withFps: 20)
        
        // Set Initial Tone Frequency Based On Slider Value
        audio.setToneFrequency(tone_slider.value)

        // Handle Audio
        audio.play()
        
        // Code updates the view every 50 milliseconds
        updateViewTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] (updateViewTimer) in
            self?.updateView()
        }
    }
    
    //When we exit the screen, calls several methods
    override func viewDidDisappear(_ animated: Bool) {
        audio.pause() 
        updateViewTimer?.invalidate() 
        super.viewDidDisappear(animated)
    }
    
    // Makes function calls needed to update the view 
    @objc func updateView() {
        updateGraphs()
        updateMaxDecibels()
        measureDopplerEffect()
    }
    
    // Update Graphs
    private func updateGraphs() {
        self.graph?.updateGraph(data: self.audio.fftData, forKey: "fft")
        self.graph?.updateGraph(data: self.audio.timeData, forKey: "time")
    }
    
    // Calculate Max Decibels, Update Label
    private func updateMaxDecibels() {
        decibel_label.text = String(format: "%.2f", audio.getMaxDecibels())
    }
    
    // This function determines the Doppler effect based on the difference between left-hand side (LHS) and right-hand side (RHS) averages.
    private func measureDopplerEffect() {
        
        // Obtain the local averages on both sides of a given frequency (provided by the `tone_slider` value) from the audio model.
        // `lAvg` is the average on the LHS of the frequency and `rAvg` is the average on the RHS.
        let (lAvg, rAvg) = audio.localAverages(sliderFreq: tone_slider.value)
        
        // Determine the movement (or lack thereof) based on the difference between `lAvg` and `rAvg`.
        // If the difference is within a specific range (-3.65 to 6.35), it's determined that the source is "Still".
        // If the difference is greater than or equal to 6.35, it suggests the source is "Moving Closer!".
        // Otherwise, the source is determined to be "Moving Farther!".
        // The values -3.65 and 6.35 were determined from trial & error. 
        if -3.65 < lAvg - rAvg && lAvg - rAvg < 6.35 {
            gesture_label.text = "Still"
        } else if lAvg - rAvg >= 6.35 {
            gesture_label.text = "Moving Closer!"
        } else {
            gesture_label.text = "Moving Farther!"
        }
    }

}
