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
    
    /// Weight Function For Lookback
    private func weightFunc(x:Float, numVals:Int) -> Float{
        // return Float(((-1 * x) + numVals) / Float(numVals))
        return ((-1 * x) + Float(numVals + 1)) / Float(numVals + 1)
    }

    /// Initialize AudioModel With Buffer Size, Lookback Window For Weighted Average Of Previous Sound Values - Anything Not Lazily Instantiated Should Be Allocated Here
    init(buffer_size:Int, lookback:Int = 10) {
        BUFFER_SIZE = buffer_size
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE / 2)
        weights = []
        weightsSum = 0
        frozenFftData = []
        frozenTimeData = []
        self.lookback = lookback
        for i in 1...lookback {
            let wt = weightFunc(x: Float(i), numVals: lookback)
            weights.append(wt)
            weightsSum += wt
        }
    }

    /// Populate self.peak1Freq and self.peak2Freq with a given windowSize for finding the max value
    public func calcLoudestSounds(windowSize:Int=3){
        var freqRes:Float = -10.0
        var peakLookup = Dictionary<Float, Int>(minimumCapacity: frozenFftData.count)
        
        var peaks:[Float] = []
        freqRes = Float((self.audioManager?.samplingRate)!) / Float(self.BUFFER_SIZE)
        for i in 0...(frozenFftData.count - windowSize) {
            var maxValue:Float = 0.0
            vDSP_maxv(&frozenFftData + i, 1, &maxValue, vDSP_Length(windowSize))

            if maxValue == frozenFftData[i + Int(windowSize/2)] {
                peaks.append(maxValue)
                peakLookup[maxValue] = i
            }
        }

        var peak1:Float = 0.0
        vDSP_maxv(peaks, 1, &peak1, vDSP_Length(peaks.count))
        let peak1Loc = peakLookup[peak1]
        peaks = peaks.filter { $0 != peak1 }
        
        var peak2:Float = 0.0
        vDSP_maxv(peaks, 1, &peak2, vDSP_Length(peaks.count))
        let peak2Loc = peakLookup[peak2]

        self.peak1Freq = quadraticApprox(peakLocation: peak1Loc!, deltaF: freqRes)
        self.peak2Freq = quadraticApprox(peakLocation: peak2Loc!, deltaF: freqRes)
        
    }
    /// Used to approximate the actual peak hz based on the points around the peak
    private func quadraticApprox(peakLocation:Int,deltaF:Float) -> Float {
        let m1 = frozenFftData[peakLocation-1]
        let m2 = frozenFftData[peakLocation]
        let m3 = frozenFftData[peakLocation + 1]
        
        let f2 = Float(peakLocation) * deltaF
        
        return f2 + ((m1-m2)/(m3 - 2 * m2 + m1)) * (deltaF / 2.0)
    }
    /// Check if a sufficiently large sound was detected by the microphone (above a certain float threshold for average sin wave)
    public func isLoudSound(cutoff:Float) -> Bool {
        var maxTimeVal:Float = 0.0
        vDSP_maxv(timeData, 1, &maxTimeVal, vDSP_Length(timeData.count))
        var isTrue = false
        var weightedTimeVals:[Float] = prevMaxTimeData
        vDSP_vmul(prevMaxTimeData, 1, weights, 1, &weightedTimeVals, 1, vDSP_Length(prevMaxTimeData.count))
        let wtAvg = vDSP.sum(weightedTimeVals) / weightsSum
    
        let pctDiff = (maxTimeVal - wtAvg) / wtAvg
        
        
        if pctDiff > cutoff {
            isTrue = true
            self.frozenFftData = fftData
            self.frozenTimeData = timeData
        }
        prevMaxTimeData.insert(maxTimeVal, at: 0)
        if prevMaxTimeData.count > self.lookback {
            _ = prevMaxTimeData.popLast()
        }
        
        return isTrue
    }
    
    /// Calculate, Return Maximum Decibel Value From FFT Data
    func getMaxDecibels() -> Float {
        
        // Calculate Magnitude For Each Bin
        let magnitudes = fftData.map { $0 * $0 }

        // Calculate Decibel Value For Each Magnitude
        let decibels = magnitudes.map { 20.0 * log10(sqrt($0) + 1e-9) }

        // Return Maximum Decibel Value
        return decibels.max() ?? -Float.infinity
    }
    
    /// Obtain Local Averages (LHS, RHS)
    func localAverages(sliderFreq:Float) -> (Float, Float) {
        
        // Calculate FFT Index (Frequency (k) * N / Sampling Frequency)
        let index = Int(sliderFreq * Float(BUFFER_SIZE) / Float(self.audioManager!.samplingRate))
        
        // No. Data Points On RHS / LHS
        // Chosen For Not Too Much Information
        let range = 20
        
        // Calculate The Average For LHS / RHS For Specific Frequency (Slider) - Note: Generated With Help From GPT
        let lhsAvg = fftData[(index - range)..<index].reduce(0, +) / Float(range)
        let rhsAvg = fftData[(index + 1)..<(index + range + 1)].reduce(0, +) / Float(range)
        
        // Return Positive (Easier To Use)
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
