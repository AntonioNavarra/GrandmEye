import CoreMotion

/// Tells whether the phone is being held still, using the gyroscope and accelerometer.
@MainActor
final class SteadinessMonitor {
    private let motion = CMMotionManager()

    /// False on devices/simulators without motion sensors.
    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.05
        motion.startDeviceMotionUpdates()
    }

    func stop() { motion.stopDeviceMotionUpdates() }

    /// True when rotation and acceleration are both below the "hand is resting" thresholds.
    /// Thresholds are lenient so that a mild tremor can still reach a steady moment.
    var isSteady: Bool {
        guard let m = motion.deviceMotion else { return false }
        let r = m.rotationRate
        let a = m.userAcceleration
        let rotation = (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot()
        let accel = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
        return rotation < 0.35 && accel < 0.06
    }
}
