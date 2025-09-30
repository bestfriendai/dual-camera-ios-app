import AVFoundation

let session = AVCaptureMultiCamSession()
if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
    let input = try AVCaptureDeviceInput(device: device)
    let ports = input.ports(for: .video, sourceDeviceType: device.deviceType, sourceDevicePosition: .front)
    print(ports)
}
