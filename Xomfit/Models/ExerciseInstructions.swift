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
    /// Deliberately covers the compound lifts, the movements people most often
    /// perform badly, and every exercise the built-in templates prescribe —
    /// rather than all 211. A generic three-step template stamped across every
    /// isolation variant would read as filler and teach nothing;
    /// `instructions(for:)` falls back to the exercise's own description and
    /// tips, which is honest about what is actually known.
    ///
    /// The template-coverage half is enforced by a test: if a programme starts
    /// prescribing a movement with no instructions, that fails rather than
    /// quietly shipping a programme the app cannot explain.
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
        ),

        // MARK: - Exercises the built-in templates actually prescribe
        //
        // Selected by auditing `WorkoutTemplate` rather than by picking
        // favourites: these are the movements a lifter following the app's own
        // programmes is told to perform, so they are the ones most likely to be
        // performed without knowing how.

        "ex-incline-db": ExerciseInstructions(
            setup: [
                "Set the bench to about 30°. Steeper turns it into a shoulder press.",
                "Sit with the dumbbells on your thighs, then kick them up one at a time as you lie back.",
                "Pull your shoulder blades down and together before the first rep.",
                "Start with the weights over your shoulders, palms facing forward."
            ],
            execution: [
                "Lower until your upper arms are roughly level with your torso.",
                "Keep your elbows about 45° from your sides, not flared straight out.",
                "Press up and slightly inward, without clanging the dumbbells together.",
                "Stop just short of locking out to keep tension on the chest."
            ],
            mistakes: [
                "Setting the bench so steep the front delts take over from the chest.",
                "Letting the elbows drift behind the torso at the bottom.",
                "Pressing the dumbbells together at the top and losing all tension.",
                "Arching hard off the bench to move a weight the chest cannot."
            ]
        ),

        "ex-cable-row": ExerciseInstructions(
            setup: [
                "Sit with a soft bend in the knees — locked-out legs make your lower back do the work.",
                "Brace both feet on the platform and sit tall, chest up.",
                "Take the handle with your arms extended and let the weight stretch your lats.",
                "Set your torso upright; it stays there for the whole set."
            ],
            execution: [
                "Start the pull with your shoulder blades, not your hands.",
                "Draw the handle to your lower ribs, elbows close to your sides.",
                "Pause briefly with the blades squeezed together.",
                "Let the weight pull your arms straight again under control."
            ],
            mistakes: [
                "Rocking the torso back and forth to swing the stack.",
                "Pulling with the biceps and never retracting the shoulder blades.",
                "Shrugging the shoulders up toward the ears during the pull.",
                "Rounding the lower back as the arms extend at the front."
            ]
        ),

        "ex-barbell-curl": ExerciseInstructions(
            setup: [
                "Stand with feet hip-width, bar in a shoulder-width underhand grip.",
                "Let the bar hang at arm's length against your thighs.",
                "Tuck your elbows against your ribs and brace your midsection.",
                "Set the shoulders back and down before the first rep."
            ],
            execution: [
                "Curl the bar up by bending only at the elbow.",
                "Keep your upper arms still — the elbows stay pinned to your sides.",
                "Squeeze at the top without letting the elbows travel forward.",
                "Lower all the way to straight arms under control."
            ],
            mistakes: [
                "Swinging the hips and leaning back to launch the bar.",
                "Letting the elbows drift forward, turning it into a front raise.",
                "Cutting the bottom half of the rep and never straightening the arms.",
                "Going so heavy the wrists collapse backward under the bar."
            ]
        ),

        "ex-tricep-pushdown": ExerciseInstructions(
            setup: [
                "Set the pulley at roughly head height.",
                "Take the bar or rope and step back half a pace to load the cable.",
                "Stand tall with a slight forward lean from the hips.",
                "Pin your elbows to your sides — that is the whole exercise."
            ],
            execution: [
                "Push down by straightening the elbows only.",
                "Extend fully and hold for a beat at the bottom.",
                "With a rope, pull the ends apart as you reach lockout.",
                "Let the weight return until your forearms pass parallel, keeping the elbows fixed."
            ],
            mistakes: [
                "Letting the elbows flare out and drift away from the body.",
                "Leaning over the bar and pressing with bodyweight instead of triceps.",
                "Stopping short of lockout, which is where the triceps do the most.",
                "Letting the weight yank the arms up past the point the elbows stay set."
            ]
        ),

        "ex-leg-curl": ExerciseInstructions(
            setup: [
                "Line the machine's pivot up with your knee joint before loading it.",
                "Set the pad just above your heels, not on your calves.",
                "Hold the handles and keep your hips pressed into the bench.",
                "Point your toes neutrally — hard pointing cramps the calves."
            ],
            execution: [
                "Curl your heels toward your glutes.",
                "Squeeze the hamstrings at the fully bent position.",
                "Lower slowly; the negative is most of the value here.",
                "Stop just short of the weight resting on the stack."
            ],
            mistakes: [
                "Lifting the hips off the pad to gain leverage.",
                "Letting the weight drop back rather than lowering it.",
                "Setting the pad too high so it digs into the calf.",
                "Using so much weight the movement becomes a hip thrust."
            ]
        ),

        "ex-hammer-curl": ExerciseInstructions(
            setup: [
                "Stand with a dumbbell in each hand, palms facing your thighs.",
                "Keep that neutral grip throughout — thumbs stay up.",
                "Tuck the elbows to your sides and brace your midsection.",
                "Set the shoulders back before starting."
            ],
            execution: [
                "Curl one or both dumbbells straight up toward the shoulder.",
                "Keep the palms facing inward the entire way.",
                "Squeeze at the top without swinging the elbow forward.",
                "Lower to full extension under control."
            ],
            mistakes: [
                "Rotating the wrist into a normal curl partway up.",
                "Rocking the torso to get the weight moving.",
                "Letting the elbows travel forward at the top.",
                "Bouncing out of the bottom instead of controlling it."
            ]
        ),

        "ex-cable-high-fly": ExerciseInstructions(
            setup: [
                "Set both pulleys above shoulder height.",
                "Take a handle in each hand and step forward into a split stance.",
                "Lean very slightly forward from the hips, chest up.",
                "Start with arms out wide and a soft, fixed bend in the elbows."
            ],
            execution: [
                "Sweep both hands down and together toward your lower chest.",
                "Keep the elbow angle constant — it is a fly, not a press.",
                "Cross or touch the hands at the bottom and squeeze.",
                "Let the cables pull your arms back out wide under control."
            ],
            mistakes: [
                "Bending and straightening the elbows, turning it into a pushdown.",
                "Standing too upright so the cables pull you backward.",
                "Going so heavy the shoulders roll forward at the stretch.",
                "Rushing the return and losing the stretch entirely."
            ]
        ),

        "ex-cable-low-fly": ExerciseInstructions(
            setup: [
                "Set both pulleys at the lowest position.",
                "Take a handle in each hand and step forward into a split stance.",
                "Stand tall with your chest up and arms down at your sides.",
                "Fix a slight bend in the elbows and keep it there."
            ],
            execution: [
                "Sweep both hands up and together toward chest height.",
                "Lead with the hands travelling in an arc, not a straight press.",
                "Squeeze the upper chest at the top.",
                "Lower under control until you feel the stretch across the chest."
            ],
            mistakes: [
                "Turning it into a front raise by pulling with the shoulders.",
                "Straightening the elbows to cheat the weight up.",
                "Leaning back as the hands rise.",
                "Letting the arms drop fast and losing tension at the bottom."
            ]
        ),

        "ex-chest-supported-row": ExerciseInstructions(
            setup: [
                "Set an incline bench to roughly 30–45°.",
                "Lie chest-down with your feet planted and chest firmly on the pad.",
                "Let the dumbbells hang straight down at arm's length.",
                "Keep your head in line with your spine, not craned up."
            ],
            execution: [
                "Pull the dumbbells toward your hips, leading with the elbows.",
                "Retract the shoulder blades as you row.",
                "Pause with the blades squeezed together.",
                "Lower to a full stretch without letting the chest come off the pad."
            ],
            mistakes: [
                "Peeling the chest off the pad to add a hip drive — the support is the point.",
                "Rowing with the biceps and skipping the shoulder blade retraction.",
                "Flaring the elbows straight out, which turns it into a rear delt fly.",
                "Shortening the bottom of the rep and losing the stretch."
            ]
        ),

        "ex-cable-reverse-fly": ExerciseInstructions(
            setup: [
                "Set both pulleys to about shoulder height.",
                "Cross the cables: right hand takes the left pulley and vice versa.",
                "Stand tall with a soft bend in the elbows.",
                "Start with your arms crossed in front of your chest."
            ],
            execution: [
                "Sweep both arms out and back in a wide arc.",
                "Lead with the elbows and think about the back of the shoulder.",
                "Finish with the arms out to the sides, blades squeezed.",
                "Return under control without letting the cables snap the arms forward."
            ],
            mistakes: [
                "Bending the elbows to row instead of keeping the arc.",
                "Shrugging so the traps take over from the rear delts.",
                "Using enough weight that the torso swings to start each rep.",
                "Stopping the arc early and never reaching the squeeze."
            ]
        ),

        "ex-pullover-machine": ExerciseInstructions(
            setup: [
                "Adjust the seat so the pivot lines up with your shoulder joint.",
                "Sit back with your spine against the pad and belt in if there is one.",
                "Take the handles overhead with the elbows slightly bent.",
                "Brace your midsection so the ribs stay down."
            ],
            execution: [
                "Pull the handles down and forward in an arc toward your hips.",
                "Keep the elbow angle fixed — the movement happens at the shoulder.",
                "Squeeze the lats at the bottom of the arc.",
                "Let the weight return overhead until you feel the lats stretch."
            ],
            mistakes: [
                "Bending the elbows and turning it into a triceps movement.",
                "Letting the ribs flare and the lower back arch off the pad.",
                "Setting the seat so the shoulder is out of line with the pivot.",
                "Cutting the overhead stretch, which is most of the exercise."
            ]
        ),

        "ex-leg-press": ExerciseInstructions(
            setup: [
                "Sit with your back and hips flat against the pad.",
                "Place your feet shoulder-width, roughly in the middle of the platform.",
                "Push the sled up and release the safeties before the first rep.",
                "Keep a small bend in the knees at the top — never lock them hard."
            ],
            execution: [
                "Lower the sled until your knees reach about 90°.",
                "Track your knees in line with your toes, not caving inward.",
                "Press through your whole foot, mid-foot and heel.",
                "Stop short of locking the knees at the top."
            ],
            mistakes: [
                "Letting the hips curl up off the pad at the bottom — the classic way to hurt your back here.",
                "Slamming into a hard lockout with straight knees.",
                "Letting the knees collapse toward each other under load.",
                "Placing the feet so low the heels lift off the platform."
            ]
        ),

        "ex-leg-ext": ExerciseInstructions(
            setup: [
                "Set the seat so the pivot is level with your knee.",
                "Position the pad on your shins just above the ankle.",
                "Sit back against the pad and hold the handles.",
                "Keep both feet neutral, toes pointing forward."
            ],
            execution: [
                "Extend the knees until the legs are straight.",
                "Squeeze the quads at the top for a beat.",
                "Lower slowly — resist the weight the whole way down.",
                "Stop just before the stack touches down."
            ],
            mistakes: [
                "Swinging the weight up with a hip thrust.",
                "Letting the weight crash back down between reps.",
                "Setting the pad on the ankle joint rather than above it.",
                "Slamming into a hard lockout with heavy weight."
            ]
        ),

        "ex-calf-raise": ExerciseInstructions(
            setup: [
                "Set the shoulder pads so you can stand tall with a slight knee bend.",
                "Put the balls of your feet on the platform edge, heels hanging free.",
                "Stand up to unload the safeties.",
                "Point your toes straight ahead unless you are deliberately varying them."
            ],
            execution: [
                "Drop your heels below the platform until you feel a calf stretch.",
                "Press up onto your toes as high as you can.",
                "Pause at the top for a full beat.",
                "Lower slowly back into the stretch."
            ],
            mistakes: [
                "Bouncing out of the bottom on the Achilles rather than lifting.",
                "Cutting the range short at both ends and doing tiny pulses.",
                "Bending the knees to help, turning it into a partial press.",
                "Rushing reps — calves respond to the pause, not the count."
            ]
        ),

        "ex-skull-crusher": ExerciseInstructions(
            setup: [
                "Lie flat with an EZ bar or barbell held at arm's length over your chest.",
                "Take a grip about shoulder width, palms facing your feet.",
                "Tuck the elbows in so the upper arms are near vertical.",
                "Plant your feet and brace before unracking to position."
            ],
            execution: [
                "Bend only at the elbow, lowering the bar toward your forehead or just behind it.",
                "Keep the upper arms still throughout.",
                "Stop when your forearms pass roughly parallel to the floor.",
                "Extend back to straight arms without letting the elbows drift."
            ],
            mistakes: [
                "Letting the elbows flare wide, which shifts load off the triceps.",
                "Turning it into a pullover by swinging the upper arms back.",
                "Going heavy enough that the bar drops toward the face uncontrolled.",
                "Bouncing at the bottom rather than reversing under control."
            ]
        ),

        "ex-db-shoulder-press": ExerciseInstructions(
            setup: [
                "Sit on an upright bench with back support, or stand braced.",
                "Bring the dumbbells to shoulder height, palms facing forward.",
                "Set your elbows slightly in front of your torso, not straight out to the sides.",
                "Brace your midsection and keep the ribs down."
            ],
            execution: [
                "Press both dumbbells up and slightly together.",
                "Finish with the weights over your shoulders, arms near straight.",
                "Lower under control until the elbows are level with your shoulders.",
                "Keep the wrists stacked over the elbows throughout."
            ],
            mistakes: [
                "Arching the lower back to press a weight the shoulders cannot.",
                "Flaring the elbows dead level with the shoulders and grinding the joint.",
                "Letting the dumbbells drift forward, turning it into an incline press.",
                "Bouncing out of the bottom instead of controlling the descent."
            ]
        ),

        "ex-landmine-press": ExerciseInstructions(
            setup: [
                "Wedge one end of a barbell into a landmine sleeve or a corner.",
                "Take the free end at shoulder height in one or both hands.",
                "Stand in a split or staggered stance, chest up.",
                "Brace your midsection — the load wants to twist you."
            ],
            execution: [
                "Press the bar up and forward along its natural arc.",
                "Finish with the arm near straight, shoulder moving freely.",
                "Resist any rotation through the torso.",
                "Lower back to the shoulder under control."
            ],
            mistakes: [
                "Letting the torso twist toward the pressing arm.",
                "Leaning back to turn it into an overhead press.",
                "Losing the brace and letting the lower back arch.",
                "Standing too close, which cramps the arc at the bottom."
            ]
        ),

        "ex-incline-machine-press": ExerciseInstructions(
            setup: [
                "Adjust the seat so the handles sit level with your upper chest.",
                "Sit back with your shoulder blades pinned against the pad.",
                "Plant both feet and take the handles with a full grip.",
                "Keep the elbows a touch below shoulder height."
            ],
            execution: [
                "Press the handles forward and slightly up.",
                "Stop just short of locking the elbows out.",
                "Lower until you feel a stretch across the chest.",
                "Keep the shoulder blades pinned the whole set."
            ],
            mistakes: [
                "Setting the seat so the handles start above the shoulders.",
                "Letting the shoulder blades come unglued at the stretch.",
                "Flaring the elbows straight out to the sides.",
                "Cutting the range and pressing only the top few inches."
            ]
        ),

        "ex-machine-shoulder-press": ExerciseInstructions(
            setup: [
                "Set the seat so the handles start at about shoulder height.",
                "Sit back with your spine supported and feet planted.",
                "Take the handles with the wrists stacked over the elbows.",
                "Brace your midsection and keep the ribs down."
            ],
            execution: [
                "Press straight up, following the machine's path.",
                "Stop just short of a hard lockout.",
                "Lower until the elbows are roughly level with the shoulders.",
                "Keep your back against the pad throughout."
            ],
            mistakes: [
                "Starting with the handles too low and grinding the bottom range.",
                "Pushing the head forward to help the press.",
                "Peeling the back off the pad at the top.",
                "Letting the weight slam back down at the bottom."
            ]
        ),

        "ex-cable-lateral-raise": ExerciseInstructions(
            setup: [
                "Set a single pulley to the lowest position.",
                "Stand side-on and take the handle in the hand furthest from the stack.",
                "Let the cable cross in front of your body at the start.",
                "Keep a slight, fixed bend in the elbow."
            ],
            execution: [
                "Raise the arm out to the side, leading with the elbow.",
                "Stop at about shoulder height.",
                "Keep the little finger no lower than the thumb.",
                "Lower slowly against the cable's pull."
            ],
            mistakes: [
                "Swinging the torso to launch the arm up.",
                "Shrugging so the traps take the work from the side delt.",
                "Raising far above shoulder height and rolling the shoulder in.",
                "Letting the cable snap the arm back down."
            ]
        ),

        "ex-cable-front-raise": ExerciseInstructions(
            setup: [
                "Set a single pulley to the lowest position.",
                "Stand facing away from the stack with the cable running between your legs.",
                "Take the handle with your arm hanging straight down.",
                "Stand tall and brace your midsection."
            ],
            execution: [
                "Raise the arm straight forward to about shoulder height.",
                "Keep the elbow almost straight with a soft bend.",
                "Pause briefly at the top.",
                "Lower under control against the cable."
            ],
            mistakes: [
                "Leaning back as the arm rises to use the lower back.",
                "Raising well above shoulder height and letting the traps take over.",
                "Bending the elbow to shorten the lever and cheat the weight.",
                "Letting the weight drop rather than resisting it down."
            ]
        ),

        "ex-cable-rear-delt-fly": ExerciseInstructions(
            setup: [
                "Set both pulleys at roughly shoulder height.",
                "Cross the cables so each hand takes the opposite pulley.",
                "Stand tall with the arms crossed in front of you.",
                "Fix a slight bend in the elbows."
            ],
            execution: [
                "Pull both arms out and back in a wide arc.",
                "Think about the back of the shoulder, not the middle of the back.",
                "Finish with the arms out to the sides.",
                "Return under control without letting the cables pull you forward."
            ],
            mistakes: [
                "Rowing with bent elbows instead of holding the arc.",
                "Shrugging into the traps at the end of the pull.",
                "Using so much weight the torso rocks with every rep.",
                "Stopping the arc short of the full squeeze."
            ]
        ),

        "ex-db-shrugs": ExerciseInstructions(
            setup: [
                "Stand with a dumbbell in each hand at your sides.",
                "Feet hip-width, arms hanging straight.",
                "Stand tall with the chin tucked slightly.",
                "Brace the midsection before the first rep."
            ],
            execution: [
                "Lift both shoulders straight up toward your ears.",
                "Pause at the top for a full beat.",
                "Lower slowly to a full stretch.",
                "Keep the arms straight throughout — they are just hooks."
            ],
            mistakes: [
                "Rolling the shoulders in circles instead of lifting straight up.",
                "Bending the elbows and turning it into a partial upright row.",
                "Skipping the pause, which is where the traps actually work.",
                "Craning the neck forward under heavy weight."
            ]
        ),

        "ex-preacher-curl": ExerciseInstructions(
            setup: [
                "Set the seat so your armpits rest at the top edge of the pad.",
                "Lay the back of your upper arms flat on the pad.",
                "Take the dumbbell with your arm extended down the slope.",
                "Keep your chest against the pad."
            ],
            execution: [
                "Curl up by bending only at the elbow.",
                "Stop before the forearm reaches vertical, where tension drops off.",
                "Lower slowly all the way to a straight arm.",
                "Keep the upper arm flat on the pad throughout."
            ],
            mistakes: [
                "Lifting the elbow off the pad to gain leverage.",
                "Bouncing out of the fully stretched bottom position — the easiest way to strain a biceps tendon.",
                "Standing up off the seat to drive the weight.",
                "Curling to vertical and resting at the top."
            ]
        ),

        "ex-cable-overhead-tri-ext": ExerciseInstructions(
            setup: [
                "Set the pulley low and take a rope in both hands.",
                "Turn away from the stack and bring the rope overhead.",
                "Step forward into a split stance and lean slightly forward.",
                "Set the elbows pointing forward, close to your head."
            ],
            execution: [
                "Extend the elbows until the arms are straight overhead.",
                "Pull the rope ends apart as you lock out.",
                "Keep the upper arms fixed — only the forearms move.",
                "Lower until you feel a deep stretch behind the arm."
            ],
            mistakes: [
                "Letting the elbows flare wide and drift away from the head.",
                "Turning it into a press by driving with the shoulders.",
                "Cutting the stretch short, which is where the long head is trained.",
                "Standing too upright so the cable pulls you off balance."
            ]
        ),

        "ex-face-pull": ExerciseInstructions(
            setup: [
                "Set the pulley to roughly head height with a rope attachment.",
                "Take an end in each hand, thumbs pointing back toward you.",
                "Step back until the cable is loaded and the arms are extended.",
                "Stand tall with a slight lean back against the weight."
            ],
            execution: [
                "Pull the rope toward your forehead, not your chest.",
                "Separate your hands as you pull so the rope ends pass either side of your face.",
                "Finish with the elbows high, level with or above the shoulders.",
                "Return under control to a full stretch."
            ],
            mistakes: [
                "Pulling low to the chest, which makes it a row rather than a rear delt movement.",
                "Dropping the elbows below shoulder height at the finish.",
                "Going heavy enough that the torso rocks backward each rep.",
                "Keeping the hands together instead of pulling them apart."
            ]
        ),

        "ex-front-squat": ExerciseInstructions(
            setup: [
                "Set the bar at upper-chest height and take it across the front of your shoulders.",
                "Drive the elbows high so the upper arms are near parallel to the floor — the shelf is your shoulders, not your hands.",
                "Step back into a shoulder-width stance, toes slightly out.",
                "Brace hard; the front rack punishes a soft midsection."
            ],
            execution: [
                "Sit straight down, keeping the torso as upright as you can.",
                "Track the knees out over the toes.",
                "Descend until the hip crease passes the knee, if your mobility allows.",
                "Drive up through the whole foot, keeping the elbows high."
            ],
            mistakes: [
                "Letting the elbows drop, which rolls the bar forward and dumps it.",
                "Leaning forward like a back squat and losing the rack.",
                "Trying to grip the bar in the palms instead of resting it on the shoulders.",
                "Letting the knees collapse inward out of the bottom."
            ]
        ),

        "ex-bulgarian-split-squat": ExerciseInstructions(
            setup: [
                "Stand a stride's length in front of a bench, dumbbells at your sides.",
                "Place the top of one foot on the bench behind you.",
                "Check the distance with a slow first rep — too close jams the knee, too far strains the hip.",
                "Square your hips and stand tall."
            ],
            execution: [
                "Lower straight down by bending the front knee.",
                "Keep most of your weight through the front foot.",
                "Descend until the front thigh is about parallel.",
                "Drive up through the front heel without pushing off the back foot."
            ],
            mistakes: [
                "Standing too close so the front knee travels far past the toes.",
                "Pushing off the rear foot and turning it into a two-legged squat.",
                "Letting the hips rotate open toward the working side.",
                "Leaning so far forward it becomes a hinge rather than a squat."
            ]
        ),

        "ex-seated-calf-raise": ExerciseInstructions(
            setup: [
                "Sit with the balls of your feet on the platform, heels free.",
                "Set the knee pad snug across your lower thighs.",
                "Release the safety and take the weight.",
                "Keep your toes pointing straight forward."
            ],
            execution: [
                "Drop the heels until you feel a stretch low in the calf.",
                "Press up onto the toes as high as the pad allows.",
                "Hold the top for a full beat.",
                "Lower slowly back into the stretch."
            ],
            mistakes: [
                "Bouncing the bottom of each rep off the Achilles.",
                "Doing short pulses instead of the full range.",
                "Setting the pad on the knee rather than the lower thigh.",
                "Rushing — the seated version rewards the pause more than the load."
            ]
        ),
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
