//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//
//  Lab Two: Audio Filtering, FFT, Doppler Shifts
//  Trevor Dohm, Will Landin, Ray Irani, Alex Shockley
//

// Import Statements
import Foundation
import Accelerate

/// AudioModel Class - Handles Interaction With Novocaine
class AudioModel {
    
    // ================
    // MARK: Properties
    // ================
    
    // These Properties Are For Interfacing With Novocaine, FFTHelper, Etc.
    // User Can Access These Arrays Whenever Necessary And Plot Them
    private var BUFFER_SIZE:Int
    var timeData:[Float]
    var fftData:[Float]
    var frozenFftData:[Float]
    var frozenTimeData:[Float]
    var peak1Freq:Float = 0.0
    var peak2Freq:Float = 0.0
    private var weights:[Float]
    private var weightsSum:Float
    private var prevMaxTimeData:[Float] = []
    private var lookback:Int
    
    // ====================
    // MARK: Public Methods
    // ====================
    
    /// A function to determine the weight of a value based on its position in a lookback sequence.
    private func weightFunc(x:Float, numVals:Int) -> Float{
        // Compute and return the weight for a given x based on a total of numVals
        // This decreases the weight linearly as x approaches numVals.
        return ((-1 * x) + Float(numVals + 1)) / Float(numVals + 1)
    }
    
    /// Initializes an AudioModel object.
    ///
    /// This initializer is responsible for setting up audio-related data structures
    /// and precomputing weights based on a lookback window. These weights are 
    /// presumably used to compute a weighted average of previous sound values.
    init(buffer_size:Int, lookback:Int = 10) {
        
        // Set the buffer size to the given value.
        BUFFER_SIZE = buffer_size
        
        // Initialize timeData array with zeros to store time domain audio data.
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        
        // Initialize fftData array with zeros to store frequency domain audio data.
        // Since FFT output has a symmetric component for real signals, we only store half.
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE / 2)
        
        // Initialize an empty array to store the weights for the lookback window.
        weights = []
        
        // Initialize a variable to keep track of the total sum of weights.
        weightsSum = 0
        
        // Initialize arrays to store frozen (possibly unchanging or captured) audio data.
        frozenFftData = []
        frozenTimeData = []
        
        // Store the lookback value.
        self.lookback = lookback
        
        // Compute and store the weights based on the lookback value.
        for i in 1...lookback {
            let wt = weightFunc(x: Float(i), numVals: lookback)
            weights.append(wt)
            weightsSum += wt
        }
    }

    /// The method identifies peaks in the FFT data, then narrows down to the two most prominent peaks.
    public func calcLoudestSounds(windowSize:Int=3){
        
        // Initial frequency resolution value
        var freqRes:Float = -10.0
        
        // Dictionary to lookup the index of a peak based on its magnitude
        var peakLookup = Dictionary<Float, Int>(minimumCapacity: frozenFftData.count)
        
        // Array to store detected peaks
        var peaks:[Float] = []
        
        // Calculate frequency resolution
        freqRes = Float((self.audioManager?.samplingRate)!) / Float(self.BUFFER_SIZE)
        
        // Scan the FFT data to identify peaks using a window
        for i in 0...(frozenFftData.count - windowSize) {
            var maxValue:Float = 0.0
            vDSP_maxv(&frozenFftData + i, 1, &maxValue, vDSP_Length(windowSize))
    
            // If the maximum value is in the center of the window, it's a peak
            if maxValue == frozenFftData[i + Int(windowSize/2)] {
                peaks.append(maxValue)
                peakLookup[maxValue] = i
            }
        }
    
        // Find the loudest peak
        var peak1:Float = 0.0
        vDSP_maxv(peaks, 1, &peak1, vDSP_Length(peaks.count))
        let peak1Loc = peakLookup[peak1]
        // Remove the loudest peak to find the second loudest peak next
        peaks = peaks.filter { $0 != peak1 }
        
        // Find the second loudest peak
        var peak2:Float = 0.0
        vDSP_maxv(peaks, 1, &peak2, vDSP_Length(peaks.count))
        let peak2Loc = peakLookup[peak2]
    
        // Approximate the actual frequency values of the peaks
        self.peak1Freq = quadraticApprox(peakLocation: peak1Loc!, deltaF: freqRes)
        self.peak2Freq = quadraticApprox(peakLocation: peak2Loc!, deltaF: freqRes)
    }
    
    /// Approximates the frequency of a peak using quadratic interpolation around the peak.
    /// This provides a more accurate estimation of the peak's true frequency.
    private func quadraticApprox(peakLocation:Int, deltaF:Float) -> Float {
        // Magnitudes at and around the peak
        let m1 = frozenFftData[peakLocation-1]
        let m2 = frozenFftData[peakLocation]
        let m3 = frozenFftData[peakLocation + 1]
        
        let f2 = Float(peakLocation) * deltaF
        
        // Quadratic interpolation formula to approximate peak frequency
        return f2 + ((m1-m2)/(m3 - 2 * m2 + m1)) * (deltaF / 2.0)
    }
    
    /// Checks if a loud sound, above a specified threshold, has been detected in the time domain data.
    public func isLoudSound(cutoff:Float) -> Bool {
        // Initializing a variable to store the maximum value from the timeData array.
        var maxTimeVal:Float = 0.0
    
        // Using vDSP_maxv to efficiently calculate the maximum value in the timeData array.
        vDSP_maxv(timeData, 1, &maxTimeVal, vDSP_Length(timeData.count))
        
        // Default return value indicating the sound isn't loud enough.
        var isTrue = false
        
        // Create an array to store the weighted time values.
        var weightedTimeVals:[Float] = prevMaxTimeData
        
        // Multiply the previous max time data by the corresponding weight.
        // This gives a significance to each data point based on its historical position.
        vDSP_vmul(prevMaxTimeData, 1, weights, 1, &weightedTimeVals, 1, vDSP_Length(prevMaxTimeData.count))
        
        // Compute the sum of the weighted time values.
        let wtAvg = vDSP.sum(weightedTimeVals) / weightsSum
        
        // Calculate the percentage difference between the current max value and the weighted average.
        let pctDiff = (maxTimeVal - wtAvg) / wtAvg
        
        // If the percentage difference exceeds the given cutoff, we determine that a loud sound is detected.
        if pctDiff > cutoff {
            isTrue = true
            
            // Save the current FFT and time data to be accessed later (i.e., "freeze" them).
            self.frozenFftData = fftData
            self.frozenTimeData = timeData
        }
        
        // Update the previous maximum time data array with the current maximum value.
        prevMaxTimeData.insert(maxTimeVal, at: 0)
        
        // Ensure the prevMaxTimeData array doesn't grow indefinitely.
        // Remove the oldest value if it exceeds the lookback length.
        if prevMaxTimeData.count > self.lookback {
            _ = prevMaxTimeData.popLast()
        }
        
        // Return the result, indicating if a loud sound was detected or not.
        return isTrue
    }


    
    
    /// Calculate and return the maximum decibel value from FFT data.
    func getMaxDecibels() -> Float {
    
        // Calculate the magnitude for each bin in the FFT data. This is done by squaring each value, 
        // which effectively computes the power of the signal at each frequency bin.
        let magnitudes = fftData.map { $0 * $0 }
    
        // Convert each magnitude to decibels. The addition of 1e-9 prevents the logarithm from crashing 
        // due to log of zero. The factor of 20 is used because decibels for power ratios is computed 
        // as 10*log10, but since we're using amplitude magnitudes (sqrt of power) we multiply by 20.
        let decibels = magnitudes.map { 20.0 * log10(sqrt($0) + 1e-9) }
    
        // Return the maximum decibel value. If the decibels array is empty, return negative infinity.
        return decibels.max() ?? -Float.infinity
    }

    
    /// Obtain local averages on both the left-hand side (LHS) and right-hand side (RHS) of a specified frequency in the FFT data.
    func localAverages(sliderFreq:Float) -> (Float, Float) {
        
        // Convert the provided frequency (from a slider or user input) to an index within the FFT array.
        // The formula used is: (Frequency (k) * Total FFT Points (N) / Sampling Frequency).
        let index = Int(sliderFreq * Float(BUFFER_SIZE) / Float(self.audioManager!.samplingRate))
        
        // Define the number of data points to be considered on either side of the specified frequency for the average.
        // This range is set to 20 data points to ensure not too much information is included in the average calculation.
        let range = 20
        
        // Calculate the average value of the FFT data on the LHS of the specified frequency.
        // This is achieved by taking the sum of the FFT values within the range and dividing by the range.
        let lhsAvg = fftData[(index - range)..<index].reduce(0, +) / Float(range)
        
        // Similarly, calculate the average value of the FFT data on the RHS of the specified frequency.
        let rhsAvg = fftData[(index + 1)..<(index + range + 1)].reduce(0, +) / Float(range)
        
        // Return the absolute values of both averages (this ensures the values are positive and easier to use in subsequent steps).
        return (abs(lhsAvg), abs(rhsAvg))
    }

    
    /// Public Function For Starting Processing Microphone Data
    func startMicrophoneProcessing(withFps:Double) {

        // Setup Microphone For Copy To Circular Buffer
        // Note: We Don't Use "?" Operator Here Since We
        // Don't Want Timer To Run If Microphone Not Handled
        if let manager = self.audioManager {
            manager.inputBlock = self.handleMicrophone
            
            // Repeat FPS Times / Second Using Timer Class
            Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
        }
    }
    
    /// Public Function For Starting Processing For Both Microphone, Speaker Data
    func startDualProcessing(withFps:Double, withFreq:Float = 17500.0) {
        
        // Setup Microphone, Speaker For Copy To Circular Buffer
        // Note: See Above For "If Let" Reasoning, Discussion
        if let manager = self.audioManager {
            manager.inputBlock = self.handleMicrophone

            // Set Sinewave Frequency To Current Slider Value
            sineFrequency = withFreq
            
            // Use Novocaine Implementation (C) Rather Than Swift Implementation (Swift)
            // Similar Methods, But In Terms Of Speed, C > Swift
            // manager.outputBlock = self.handleSpeakerQueryWithSinusoids
            manager.setOutputBlockToPlaySineWave(sineFrequency)
            
            // Repeat FPS Times / Second Using Timer Class
            Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
        }
    }
    
    /// Set Inaudible Tone Frequency
    func setToneFrequency(_ frequency: Float) {
        sineFrequency = frequency
    }
    
    /// Get Circular Buffer
    func retrieveInputBuffer() -> CircularBuffer? {
        return inputBuffer
    }
    
    /// Start Handling Audio
    func play() {
        self.audioManager?.play()
    }
    
    /// Stop Handling Audio
    func pause(){
        self.audioManager?.pause()
    }
    
    // ========================
    // MARK: Private Properties
    // ========================
    
    /// Instantiate Novocaine AudioManager
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    /// Instantiate FFTHelper
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    /// Instantiate Input CircularBuffer (Input Buffer For AudioManager)
    private lazy var inputBuffer:CircularBuffer? = {
        
        // Can Create More With This Logic If Necessary
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    // ============================
    // MARK: Model Callback Methods
    // ============================
    
    /// Call This Every FPS Times Per Second
    private func runEveryInterval() {
        if inputBuffer != nil {

            // Copy Time Data To Swift Array
            // timeData: Raw Audio Samples
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // Copy FFT Data To Swift Array
            // fftData: FFT Of Those Same Samples
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
        }
    }
    
    // =========================
    // MARK: Audiocard Callbacks
    // =========================
    
    /// ObjC: (^InputBlock)(float * data, UInt32 numFrames, UInt32 numChannels) - Swift
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {

        // Copy Samples From Microphone Into Circular Buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }

    /// Frequency In Hertz (Changable By User)
    var sineFrequency:Float = 0.0 {
        didSet{
            
            // Set Sine Frequency From AudioManager
            self.audioManager?.sineFrequency = sineFrequency
        }
    }
    
    // SWIFT SINE WAVE
    // everything below here is for the swift implementation
    // this can be deleted when using the objective c implementation
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    
    private func handleSpeakerQueryWithSinusoids(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        // while pretty fast, this loop is still not quite as fast as
        // writing the code in c, so I placed a function in Novocaine to do it for you
        // use setOutputBlockToPlaySineWave() in Novocaine
        // EDIT: fixed in 2023
        if let arrayData = data{
            var i = 0
            let chan = Int(numChannels)
            let frame = Int(numFrames)
            if chan==1{
                while i<frame{
                    arrayData[i] = sin(phase)
                    phase += phaseIncrement
                    if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                    i+=1
                }
            }else if chan==2{
                let len = frame*chan
                while i<len{
                    arrayData[i] = sin(phase)
                    arrayData[i+1] = arrayData[i]
                    phase += phaseIncrement
                    if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                    i+=2
                }
            }
        }
    }
}
