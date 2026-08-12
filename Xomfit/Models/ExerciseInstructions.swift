import Foundation

/// Step-by-step form guidance for an exercise.
///
/// `Exercise` already carries a one-line `description` and a flat `tips` array.
/// That is enough to jog the memory of someone who already knows the lift, but
/// not enough to teach it — and "how do I actually do this" is the question the
/// detail sheet gets opened for. Splitting setup from execution from the common
/// mistakes is what makes it readable mid-set.
struct ExerciseInstructions: Codable, Hashable {
    /// How to get into position before the first rep.
    var setup: [String]
    /// The rep itself, in order.
    var execution: [String]
    /// What usually goes wrong. Phrased as the mistake, not the fix, because
    /// people recognize their own error faster than they recognize advice.
    var mistakes: [String]

    var isEmpty: Bool {
        setup.isEmpty && execution.isEmpty && mistakes.isEmpty
    }
}

// MARK: - Library

enum ExerciseInstructionLibrary {

    /// Hand-written instructions, keyed by exercise id.
    ///
    /// Deliberately covers the compound lifts and the movements people most
    /// often perform badly, rather than all 194. A generic three-step template
    /// stamped across every isolation variant would read as filler and teach
    /// nothing — `instructions(for:)` falls back to the exercise's own
    /// description and tips, which is honest about what is actually known.
    static let library: [String: ExerciseInstructions] = [

        "ex-bench-flat": ExerciseInstructions(
            setup: [
                "Lie back with your eyes directly under the bar.",
                "Grip slightly wider than shoulder width, wrists stacked over your elbows.",
                "Plant both feet flat and pull your shoulder blades down and together.",
                "Unrack to a position over your shoulders, not your face."
            ],
            execution: [
                "Lower under control to your mid-chest, elbows about 45° from your torso.",
                "Touch the chest without bouncing.",
                "Press up and slightly back, finishing over your shoulders.",
                "Keep your shoulder blades pinned throughout."
            ],
            mistakes: [
                "Flaring the elbows straight out to the sides, which stresses the shoulder.",
                "Letting the shoulder blades come unglued at the top.",
                "Bouncing the bar off the ribcage to get out of the bottom.",
                "Lifting the hips off the bench to force a rep."
            ]
        ),

        "ex-squat": ExerciseInstructions(
            setup: [
                "Set the bar just below shoulder height and take it across your upper back, not your neck.",
                "Step back with two or three deliberate steps.",
                "Feet about shoulder width, toes turned slightly out.",
                "Take a big breath into your belly and brace as if about to be punched."
            ],
            execution: [
                "Break at the hips and knees together.",
                "Sit down between your hips, keeping your chest proud.",
                "Descend until your hip crease passes below the top of your knee.",
                "Drive up through your whole foot, hips and chest rising at the same rate."
            ],
            mistakes: [
                "Knees caving inward on the way up.",
                "Hips shooting up first, turning the squat into a good morning.",
                "Rising onto the toes as the heels lift.",
                "Losing the brace at the bottom and rounding the lower back."
            ]
        ),

        "ex-deadlift": ExerciseInstructions(
            setup: [
                "Stand with the bar over mid-foot, about an inch from your shins.",
                "Feet hip width, grip just outside your knees.",
                "Drop your hips until your shins touch the bar, chest up.",
                "Pull the slack out of the bar until you hear it settle."
            ],
            execution: [
                "Push the floor away rather than pulling with your arms.",
                "Keep the bar dragging up your legs the whole way.",
                "Hips and shoulders rise together.",
                "Finish standing tall by squeezing the glutes — do not lean back."
            ],
            mistakes: [
                "Letting the bar drift forward away from the shins.",
                "Rounding the lower back to reach the bar.",
                "Jerking the bar off the floor before the slack is out.",
                "Hyperextending at the top, which loads the lower back for nothing."
            ]
        ),

        "ex-ohp": ExerciseInstructions(
            setup: [
                "Bar resting on your front delts, hands just outside shoulder width.",
                "Elbows slightly in front of the bar, not flared out.",
                "Feet hip width, glutes and abs braced.",
                "Stack the bar over mid-foot before you press."
            ],
            execution: [
                "Tilt your head back slightly so the bar has a straight path.",
                "Press up, moving your head back through once the bar clears it.",
                "Finish with the bar over the middle of your foot, biceps by your ears.",
                "Lower under control back to the front delts."
            ],
            mistakes: [
                "Pressing around the face instead of moving the head out of the way.",
                "Leaning back through the lower back to turn it into an incline press.",
                "Stopping short of a full overhead lockout.",
                "Letting the elbows flare wide, which kills the press's leverage."
            ]
        ),

        "ex-row-barbell": ExerciseInstructions(
            setup: [
                "Hinge at the hips until your torso is around 45° or lower.",
                "Grip just outside shoulder width, arms hanging straight down.",
                "Brace hard and set a flat back before the first rep."
            ],
            execution: [
                "Pull toward your lower chest or upper abs, leading with the elbows.",
                "Squeeze the shoulder blades together at the top.",
                "Lower under control until the arms are fully extended.",
                "Keep the torso angle fixed for the whole set."
            ],
            mistakes: [
                "Standing up as you pull, which turns it into a shrug.",
                "Pulling to the belly button with the elbows tucked to the ribs.",
                "Using so much momentum the weight never actually stops.",
                "Letting the lower back round as fatigue sets in."
            ]
        ),

        "ex-pullup": ExerciseInstructions(
            setup: [
                "Grip slightly wider than shoulder width, palms facing away.",
                "Hang at full stretch, then pull your shoulder blades down.",
                "Squeeze the glutes and brace so the body stays rigid."
            ],
            execution: [
                "Drive the elbows down and back toward your ribs.",
                "Pull until your chin clears the bar.",
                "Lower under control to a full hang.",
                "Keep the body still — no kipping unless that is the point."
            ],
            mistakes: [
                "Starting each rep from a dead, unpacked shoulder.",
                "Stopping short of a full hang to make reps easier.",
                "Swinging the legs to generate momentum.",
                "Craning the chin over the bar instead of pulling the chest up."
            ]
        ),

        "ex-rdl": ExerciseInstructions(
            setup: [
                "Stand tall holding the bar at the hips, feet hip width.",
                "Soften the knees slightly and keep them there.",
                "Set the shoulder blades and brace."
            ],
            execution: [
                "Push the hips straight back, letting the bar drag down your thighs.",
                "Descend until you feel a strong stretch in the hamstrings.",
                "Stop before your back starts to round — that is your range.",
                "Drive the hips forward to stand up."
            ],
            mistakes: [
                "Turning it into a squat by bending the knees through the descent.",
                "Chasing the floor and rounding the back to touch the plates down.",
                "Letting the bar drift away from the legs.",
                "Hyperextending at the top instead of just standing up."
            ]
        ),

        "ex-hip-thrust": ExerciseInstructions(
            setup: [
                "Sit on the floor with your upper back against a bench, bar over your hips.",
                "Use a pad — this one genuinely hurts without it.",
                "Feet flat, roughly shin-vertical at the top of the rep.",
                "Tuck the chin and look forward."
            ],
            execution: [
                "Drive through the heels and squeeze the glutes to lift the bar.",
                "Finish with the torso parallel to the floor.",
                "Hold the top for a beat.",
                "Lower under control without resting the bar down between reps."
            ],
            mistakes: [
                "Hyperextending the lower back instead of finishing with the glutes.",
                "Feet too far forward, which turns it into a hamstring exercise.",
                "Letting the chin drift up, which drags the ribs open.",
                "Bouncing the bar off the floor at the bottom."
            ]
        ),

        "ex-lat-pulldown": ExerciseInstructions(
            setup: [
                "Set the thigh pad snug enough that you stay seated under load.",
                "Grip slightly wider than shoulder width.",
                "Sit tall, then lean back only slightly and hold that angle."
            ],
            execution: [
                "Pull the bar to your upper chest, leading with the elbows.",
                "Let the shoulder blades rotate down and back.",
                "Control the bar back up to a full stretch.",
                "Keep the torso angle fixed — do not rock."
            ],
            mistakes: [
                "Rocking backward to heave the weight down.",
                "Pulling behind the neck, which is hard on the shoulders for no benefit.",
                "Cutting the top short and never letting the lats stretch.",
                "Curling with the arms instead of driving with the elbows."
            ]
        ),

        "ex-dips": ExerciseInstructions(
            setup: [
                "Grip the bars and press to a locked-out support position.",
                "Depress the shoulders — do not sag into the joint.",
                "Lean the torso forward slightly for chest, stay upright for triceps."
            ],
            execution: [
                "Lower until your upper arms are roughly parallel to the floor.",
                "Keep the elbows tracking back rather than flaring wide.",
                "Press back up to a full lockout.",
                "Hold the forward lean consistently across the set."
            ],
            mistakes: [
                "Sinking into the shoulders at the bottom.",
                "Going far deeper than shoulder mobility allows.",
                "Flaring the elbows straight out.",
                "Bouncing out of the bottom position."
            ]
        )
    ]

    /// Instructions for an exercise, or nil when none have been written.
    ///
    /// Returns nil rather than a synthesized placeholder so the detail sheet can
    /// fall back to the description and tips it already shows, instead of
    /// presenting generated filler as if it were coaching.
    static func instructions(for exerciseId: String) -> ExerciseInstructions? {
        library[exerciseId]
    }

    /// Whether an exercise has full step-by-step guidance.
    static func hasInstructions(for exerciseId: String) -> Bool {
        library[exerciseId] != nil
    }
}
