import SwiftUI
import SceneKit

struct GlobeView: UIViewRepresentable {
    let dives: [Dive]
    @Binding var selectedDive: Dive?

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedDive: $selectedDive, dives: dives)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = makeScene(coordinator: context.coordinator)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = UIColor(red: 0.02, green: 0.04, blue: 0.12, alpha: 1)
        view.antialiasingMode = .multisampling4X

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        context.coordinator.scnView = view

        return view
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Pin nodes are rebuilt on scene creation; nothing to update live
    }

    // MARK: - Scene Construction

    private func makeScene(coordinator: Coordinator) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = makeStarfield()

        let earthNode = makeEarth()
        addDivePins(to: earthNode, coordinator: coordinator)

        // Slow auto-rotation (user can override with camera control)
        let spin = CABasicAnimation(keyPath: "rotation")
        spin.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, Float.pi * 2))
        spin.duration = 40
        spin.repeatCount = .infinity
        earthNode.addAnimation(spin, forKey: "autoSpin")
        scene.rootNode.addChildNode(earthNode)
        coordinator.earthNode = earthNode

        scene.rootNode.addChildNode(makeAmbientLight())
        scene.rootNode.addChildNode(makeSunLight())
        scene.rootNode.addChildNode(makeCamera())

        return scene
    }

    private func makeEarth() -> SCNNode {
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 96

        let mat = SCNMaterial()
        // Use bundled earth texture; falls back to solid blue if not present
        if let tex = UIImage(named: "earth_color") {
            mat.diffuse.contents = tex
        } else {
            mat.diffuse.contents = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1)
        }
        if let spec = UIImage(named: "earth_specular") { mat.specular.contents = spec }
        if let norm = UIImage(named: "earth_normal")   { mat.normal.contents = norm }
        mat.shininess = 0.3
        sphere.materials = [mat]

        return SCNNode(geometry: sphere)
    }

    private func makeStarfield() -> UIImage? {
        let size = CGSize(width: 2048, height: 2048)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }

        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        UIColor.white.setFill()
        for _ in 0..<2000 {
            let x = CGFloat.random(in: 0..<size.width)
            let y = CGFloat.random(in: 0..<size.height)
            let r = CGFloat.random(in: 0.5...2.0)
            let alpha = CGFloat.random(in: 0.4...1.0)
            UIColor.white.withAlphaComponent(alpha).setFill()
            UIBezierPath(ovalIn: CGRect(x: x, y: y, width: r, height: r)).fill()
        }
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private func makeAmbientLight() -> SCNNode {
        let light = SCNLight()
        light.type = .ambient
        light.color = UIColor(white: 0.25, alpha: 1)
        let node = SCNNode()
        node.light = light
        return node
    }

    private func makeSunLight() -> SCNNode {
        let light = SCNLight()
        light.type = .directional
        light.color = UIColor(white: 0.95, alpha: 1)
        let node = SCNNode()
        node.light = light
        node.position = SCNVector3(5, 3, 5)
        node.look(at: .init(0, 0, 0))
        return node
    }

    private func makeCamera() -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 45
        camera.zNear = 0.1
        camera.zFar = 100
        let node = SCNNode()
        node.camera = camera
        node.position = SCNVector3(0, 0, 3)
        return node
    }

    // MARK: - Dive Pins

    private func addDivePins(to earthNode: SCNNode, coordinator: Coordinator) {
        for dive in dives {
            guard let loc = dive.location else { continue }
            let pin = makePinNode(dive: dive)
            pin.position = globe(lat: loc.latitude, lon: loc.longitude, radius: 1.03)
            // Orient pin outward from center
            let constraint = SCNLookAtConstraint(target: earthNode)
            constraint.isGimbalLockEnabled = true
            pin.constraints = [constraint]
            earthNode.addChildNode(pin)
            coordinator.pinMap[dive.id] = pin
        }
    }

    private func makePinNode(dive: Dive) -> SCNNode {
        let dot = SCNSphere(radius: 0.018)
        let mat = SCNMaterial()
        mat.diffuse.contents  = UIColor.cyan
        mat.emission.contents = UIColor(red: 0, green: 0.8, blue: 1, alpha: 0.6)
        mat.isDoubleSided = true
        dot.materials = [mat]

        let node = SCNNode(geometry: dot)
        node.name = dive.id.uuidString

        let pulse = CAKeyframeAnimation(keyPath: "scale")
        pulse.values = [
            NSValue(scnVector3: SCNVector3(1, 1, 1)),
            NSValue(scnVector3: SCNVector3(1.5, 1.5, 1.5)),
            NSValue(scnVector3: SCNVector3(1, 1, 1)),
        ]
        pulse.keyTimes = [0, 0.5, 1]
        pulse.duration = 2.0 + Double.random(in: 0...1)
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(pulse, forKey: "pulse")

        return node
    }

    // Converts lat/lon to a point on the sphere surface
    private func globe(lat: Double, lon: Double, radius: Double) -> SCNVector3 {
        let latR = lat * .pi / 180
        let lonR = lon * .pi / 180
        return SCNVector3(
            Float(radius * cos(latR) * cos(lonR)),
            Float(radius * sin(latR)),
            Float(-radius * cos(latR) * sin(lonR))
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        @Binding var selectedDive: Dive?
        let dives: [Dive]
        var pinMap: [UUID: SCNNode] = [:]
        weak var scnView: SCNView?
        weak var earthNode: SCNNode?

        init(selectedDive: Binding<Dive?>, dives: [Dive]) {
            _selectedDive = selectedDive
            self.dives = dives
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView else { return }
            let location = gesture.location(in: view)
            let hits = view.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            for hit in hits {
                if let name = hit.node.name,
                   let uuid = UUID(uuidString: name),
                   let dive = dives.first(where: { $0.id == uuid }) {
                    selectedDive = dive
                    return
                }
            }
        }
    }
}
