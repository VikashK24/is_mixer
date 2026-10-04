# Dashboard Widget Documentation

## `game_moderator_controls.dart`

### Overview

`game_moderator_controls.dart` defines `GameModeratorControls`, a Flutter
`StatefulWidget` that gives the moderator control over the lifecycle of a game round.

It coordinates:

- Night and day phases
- Killer target and question selection
- Healer and detective turns
- Countdown timers
- Player survival status
- Firestore game-state updates
- MCQ question-bank uploads

### Inputs

The widget receives two required values:

- `playerList`: all players, including their identities and current status
- `moderatorQuestionBank`: the moderator's question data

The question bank is accepted by the widget but is not directly used elsewhere
in this file. Questions are uploaded separately to Firestore and selected from
killer vote records.

### Local State

The state object stores:

- `_phaseTimer`: the active one-second countdown timer
- `_standardDuration`: the default duration for most phases, currently 30 seconds
- `_townDiscussionDuration`: the configurable day discussion duration, initially 60 seconds
- `_timerController`: controls the discussion-duration input field

Helper getters inspect the player list:

- `_areIdentitiesAllocated` prevents a round from starting until all players have an identity.
- `_activeHealers` returns living players whose identity is `healer`.
- `_isHealerAlive` determines whether the healer phase is needed.
- `_isDetectiveAlive` determines whether the detective phase is needed.

### Round Flow

The game advances through these Firestore phase values:

```text
idle
	-> killerPhase
	-> awaitingHealerStart
	-> healerPhase
	-> awaitingDetectiveStart
	-> detectivePhase
	-> awaitingVillagersStart
	-> villagersPhase
	-> roundCompleted
```

The healer and detective phases are skipped when there is no living player with
the corresponding identity.

#### 1. Starting a Round

`_startNewRound()`:

- Verifies that identities have been assigned.
- Selects a random living non-killer using `GameEngineService.selectSecretTarget()`.
- Sets the game to `killerPhase`.
- Stores the target, clears the active question, and starts a 30-second timer.

#### 2. Resolving the Killer Phase

`_onKillerPhaseComplete()`:

- Reads killer votes from the `killer_votes` Firestore subcollection.
- Counts votes for each target.
- Counts votes for each selected question.
- Chooses the most common target and question.
- Adds the selected question ID to `usedQuestionIds`.
- Advances to the healer, detective, or villagers waiting phase.

#### 3. Running the Healer Phase

`_transferToHealer()` makes the selected killer question active for the healers
and starts a 30-second timer. The phase can finish automatically or when the
moderator presses the early-completion button.

`_resolveHealerPhase()` stops the timer and advances to the detective phase when
a living detective exists; otherwise, it advances to the villagers phase.

#### 4. Running the Detective Phase

`_transferToDetective()` starts a 30-second detective phase.

`_resolveDetectivePhase()` only controls the phase transition. The detective's
investigation itself is handled by other parts of the application.

#### 5. Starting the Villagers Phase

`_transferToVillagers()`:

- Reads healer answers from the `healer_answers` Firestore subcollection.
- Requires every living healer to have answered correctly for the target to be saved.
- Starts the day discussion using `_townDiscussionDuration`.
- Publishes an announcement describing the night result.

#### 6. Finalizing the Round

`_finalizeRound()`:

- Stops the timer.
- Updates the targeted player's `isAlive` value.
- Changes the game state to `roundCompleted`.
- Publishes a final message stating whether the player was saved or terminated.

### Timer Behavior

`_startTimer()` cancels any existing timer, then updates
`game_state/current.secondsRemaining` every second. When the countdown reaches
zero, it invokes the callback supplied by the current phase.

`_stopTimer()` cancels the active timer. `dispose()` also cancels the timer and
disposes the text-field controller when the widget is removed.

### Question-Bank Upload

`_showQuestionBankUploadDialog()` opens a dialog where the moderator can paste a
JSON array of multiple-choice questions. The parsed questions are stored at:

```text
game_state/question_bank
```

Invalid JSON displays an error snackbar. Valid JSON displays a success snackbar
with the number of uploaded questions.

### User Interface

The `build()` method listens to `game_state/current` with a Firestore
`StreamBuilder`, so the control panel reacts to game-state changes in real time.

The panel displays:

- The moderator control-center heading
- An MCQ upload button
- A town discussion duration input
- The current targeted player
- The selected question
- The number of used questions
- The current phase and countdown progress
- An action button appropriate to the current phase

Only the action for the current phase is shown. For example:

- `idle`: Start Night Phase
- `killerPhase`: Lock Killer Selection
- `awaitingHealerStart`: Transfer Question to Healer
- `healerPhase`: End Healer Phase Early
- `awaitingDetectiveStart`: Start Detective Phase
- `detectivePhase`: End Detective Phase Early
- `awaitingVillagersStart`: Start Day / Villagers Phase
- `villagersPhase`: Finalize Round Early
- `roundCompleted`: Reset for Next Round

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides player identity and `isAlive` information.
- [Game engine service](../../services/game_engine_service.dart) selects the secret target.
- [JSON storage service](../../services/json_storage_service.dart) updates game state and player survival status.
- Cloud Firestore stores the shared game state, votes, questions, and answers.

### Implementation Notes

- Firestore is the shared source of truth for the current game state.
- `JsonStorageService.updateGameState()` merges updates into `game_state/current`.
- Player survival is persisted with `JsonStorageService.updateUserIdentity()`.
- The `timeout` parameters in `_resolveHealerPhase()` and `_resolveDetectivePhase()` are currently accepted but not used.
- The progress indicator divides by the 30-second standard duration even during the configurable town discussion phase, so its visual percentage may be inaccurate during that phase.

-------------------

## `healer_action_card.dart`

### Overview

`healer_action_card.dart` defines `HealerActionCard`, a Flutter
`StatefulWidget` that provides the healer's action interface during the healer
phase of a game round.

The card allows a healer to:

- View the active question selected during the killer phase
- Choose a living player to protect
- Select an answer option
- Submit the rescue attempt to Firebase
- See whether the submitted answer was correct

### Inputs

The widget receives two required values:

- `currentUser`: the healer currently using the card
- `players`: the available players who can potentially be protected

### Local State

The state object stores:

- `_selectedOption`: the answer currently selected by the healer
- `_selectedTargetId`: the ID of the player selected for protection
- `_isSubmitting`: prevents repeated submissions while Firebase is processing the answer
- `_feedbackMessage`: the success, validation, or error message shown to the healer
- `_isSuccess`: controls whether feedback is styled as a success or an error

The `_validTargets` getter filters `players` to include only users who are both
alive and not terminated.

### Reading the Active Question

The `build()` method listens to the shared game state through
`JsonStorageService.streamGameState()`.

The active question is read from the `activeQuestion` field. The widget supports
the following question formats:

- A map containing `question`, `correctAnswer`, and `options`
- A map using `text` or `question_text` for the question text
- A map using `answer` for the correct answer
- A plain string, treated as the question text without answer options

When `activeQuestion` is missing or empty, the card shows a waiting message
instead of the healer controls.

### Submitting a Rescue Attempt

`_submitAnswer()` performs the following steps:

1. Checks that an answer option has been selected.
2. Checks that a target player has been selected.
3. Marks the submission as in progress and clears old feedback.
4. Compares the selected option with the correct answer, ignoring surrounding whitespace and letter casing.
5. Stores the result in the Firestore document `game_state/current/healer_answers/{currentUser.id}`.
6. Displays feedback explaining whether the answer was correct.
7. Clears the submitting state after the Firebase request completes.

The stored answer includes:

- The healer ID and username
- The selected target ID
- The selected answer option
- The `isCorrect` result
- A Firebase server timestamp

Because the document ID is the healer's user ID, a later submission from the
same healer replaces that healer's previous answer for the current round.

### User Interface

The card is rendered as a teal-themed Material `Card` containing:

- A healer icon and action heading
- A player-protection dropdown
- The active Firebase question
- Radio buttons for available answer options
- A feedback panel after submission
- A submit button with a progress indicator while processing

The player dropdown and answer controls are shown only when a question is
available. The submit button is disabled while `_isSubmitting` is true.

### Submission Outcomes

- If no answer is selected, the card asks the healer to select an option.
- If no target is selected, the card asks the healer to choose a player.
- If the answer is correct, the card shows a green success message and records `isCorrect: true`.
- If the answer is incorrect, the card shows a red failure message and records `isCorrect: false`.
- If the Firestore write fails, the card displays the Firebase error message.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides player IDs, names, and alive or terminated status.
- [JSON storage service](../../services/json_storage_service.dart) provides the real-time game-state stream.
- Cloud Firestore provides the active question and stores healer answers in the `healer_answers` subcollection.

### Implementation Notes

- The card calculates correctness on the client by comparing the selected option with the `correctAnswer` value received in the active question.
- The moderator later evaluates the stored healer answers when resolving the night round.
- A plain-string active question can be displayed, but it has no answer options or correct answer, so the healer cannot complete a normal quiz submission from that format.

---------------------

## `identity_allocation_card.dart`

### Overview

`identity_allocation_card.dart` defines `IdentityAllocationCard`, a Flutter
`StatefulWidget` that gives the moderator controls for assigning and resetting
in-game identities.

The card manages identities such as:

- Killer
- Healer
- Detective
- Villager

It does not calculate the role distribution itself. That work is delegated to
`GameEngineService.assignGameIdentities()`.

### Input

The widget receives one required value:

- `playerList`: the current list of players whose identities can be allocated or reset

### Local State

The state object stores `_isProcessing`, which tracks whether identity updates
are being written to Firebase. While this value is true, both action buttons are
disabled and the allocation button displays a loading indicator.

### Allocating Identities

`_allocateIdentities()` performs the following steps:

1. Checks that at least four players are available.
2. Shows an orange snackbar and stops if the minimum player count is not met.
3. Sets `_isProcessing` to true.
4. Calls `GameEngineService.assignGameIdentities(widget.playerList)` to create updated player records with randomly distributed identities.
5. Writes each player's identity to Firebase using `JsonStorageService.updateUserIdentity()`.
6. Resets each allocated player's `isAlive` value to `true`.
7. Shows a success or error snackbar.
8. Clears the processing state when the operation finishes.

The game engine is responsible for enforcing the minimum player requirement and
calculating the role distribution. This widget handles the user interaction and
the persistence of the result.

### Resetting Identities

`_resetIdentities()` loops through every player and updates Firebase with:

- `identity: 'NONE'`
- `isAlive: true`

After the reset completes, the card displays a blue-grey confirmation snackbar.
The reset operation also uses `_isProcessing`, so allocation and reset cannot be
started simultaneously.

### User Interface

The widget renders an indigo-themed Material `Card` containing:

- An `Identity Allocation Control` heading
- A status chip showing `Identities Active` or `Unallocated`
- A short explanation of the available roles
- An `Allocate Identities` button with a shuffle icon
- A `Reset Identities` button with a refresh icon

The status chip is based on whether any player currently has an identity other
than `NONE`.

### Feedback and Error Handling

- Fewer than four players produces an orange validation snackbar.
- Successful allocation produces a green snackbar.
- Allocation errors produce a red snackbar containing the error.
- Successful reset produces a blue-grey snackbar.
- State updates after asynchronous work are guarded with `mounted` checks where a widget may have been removed from the widget tree.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides the player records.
- [Game engine service](../../services/game_engine_service.dart) assigns random identities and enforces the minimum player count.
- [JSON storage service](../../services/json_storage_service.dart) persists each player's identity and alive status in Firestore.

### Implementation Notes

- Identity updates are written one player at a time rather than as a single Firestore batch.
- Allocation always marks the updated players as alive, which makes it suitable for starting a fresh game setup.
- Resetting identities also marks every player as alive.
- The card is driven by the `playerList` passed by its parent; it does not listen to a Firestore user stream directly.

------------

## `killer_action_card.dart`

### Overview

`killer_action_card.dart` defines `KillerActionCard`, a Flutter
`StatefulWidget` that provides the killer's night-action interface.

The card allows a killer to:

- Choose a valid player to eliminate
- Select one multiple-choice question for the healer phase
- See the current group voting consensus
- Submit or replace their target and question selection in Firebase

### Inputs

The widget receives two required values:

- `currentUser`: the killer currently using the card
- `players`: the current list of game players

### Local State

The state object stores:

- `_selectedTargetId`: the selected elimination target
- `_selectedQuestionObj`: the selected question object
- `_questionOptions`: the four question choices displayed to the killer
- `_isSubmitting`: disables submission while the Firebase write is in progress

The card also defines `_defaultFallbackQuestions`, a built-in set of four MCQs
used when no questions are available from Firebase.

### Valid Targets

The `_validTargets` getter excludes players who are:

- The current killer
- A killer by either their in-game identity or permission role
- Terminated
- No longer alive

This prevents killers from selecting themselves, another killer, or an
ineligible player.

### Generating Question Options

`_generateQuestionOptions()` creates the question choices shown in the card:

1. Uses the Firebase question bank when it is not empty.
2. Falls back to `_defaultFallbackQuestions` when the Firebase bank is empty.
3. Removes questions whose IDs appear in `usedQuestionIds` when unused options are available.
4. Falls back to the full source pool if every question has already been used.
5. Shuffles the pool randomly.
6. Displays up to four questions and clears the current question selection.

The refresh button calls this method again to generate a new randomized set.

### Live Firebase Data

The `build()` method listens to three Firebase-backed data sources:

- The root `question_bank` collection for available MCQs
- The shared game state through `JsonStorageService.streamGameState()` for `usedQuestionIds`
- The `game_state/current/killer_votes` subcollection for live killer votes

The question-bank reader supports either a document containing a `questions`
list or individual question documents. Individual documents receive their
Firestore document ID as the question ID.

### Vote Consensus

`_calculateMajorityTarget()` counts the selected `targetUserId` values from
killer vote documents and returns the most frequently selected target.

`_calculateMajorityQuestion()` counts selected question IDs and returns the
question object with the highest vote count.

The live consensus panel displays:

- The number of submitted votes
- The leading target username
- The leading question text

If there is no consensus yet, the card displays `Pending...` values.

### Submitting a Vote

`_submitVote()` only submits when both a target and question have been selected.
It writes the result to:

```text
game_state/current/killer_votes/{currentUser.id}
```

The stored vote includes:

- The killer's ID and username
- The selected target ID
- The complete selected question object
- A Firebase server timestamp

Because the document ID is the killer's user ID, submitting again replaces that
killer's previous vote instead of creating a duplicate vote document.

### User Interface

The card is rendered as a red-themed Material `Card` containing:

- A killer night-action heading
- A live vote-count chip
- A Firebase live-consensus panel
- A target-player dropdown
- A list of radio-button MCQ choices
- A refresh button for regenerating question choices
- A submit button with a loading label while the vote is being saved

The target dropdown is initially populated from the current killer's existing
vote when one is available. The submit button is enabled only when a target and
question are selected and no submission is currently running.

### Feedback and Error Handling

- A successful write shows a green confirmation snackbar.
- A failed write shows a red snackbar containing the Firebase error.
- The submit button is disabled during the asynchronous write.
- The card uses `mounted` checks before showing snackbars or updating the processing state after asynchronous work.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides player identities, roles, IDs, and alive or terminated status.
- [JSON storage service](../../services/json_storage_service.dart) provides the real-time game-state stream.
- Cloud Firestore provides the question bank and stores killer votes.

### Implementation Notes

- The question bank is read from the root `question_bank` collection, while the selected question and vote records are stored under `game_state/current`.
- The card performs the target and question majority calculations locally for display; the moderator control card independently resolves the final result.
- A fallback question set keeps the killer interface usable when the Firebase question bank has no data.
- The selected question object is stored with the vote so the moderator can use the exact question chosen by the killer group.

----------------------

## `moderator_approval_queue.dart`

### Overview

`moderator_approval_queue.dart` defines `ModeratorApprovalQueuePage`, a
Flutter `StatefulWidget` page for reviewing and changing user approval status.

The page displays two live queues:

- Users waiting for approval
- Users who are already approved

Despite the page name, the filtering logic excludes users whose permission role
is `moderator` from both queues. The page therefore currently manages approval
for other user types, such as players.

### Local Behavior

The page has no additional local state fields. It uses a Firestore stream to
receive the current users and rebuilds whenever the `users` collection changes.

### Updating Approval Status

`_updateUserApproval()` updates the selected user document in the Firestore
`users` collection with:

- `isApproved`: the requested approval value
- `approvedAt`: a Firebase server timestamp when approved, or `null` when approval is revoked

After a successful update, the page shows:

- A green `Player approved!` snackbar when approval is granted
- An orange `Player approval revoked.` snackbar when approval is removed

If the Firestore update fails, a red snackbar displays the error message.

### Reading and Grouping Users

The `build()` method listens to the complete `users` collection through a
Firestore `StreamBuilder` and converts each document into a `User` object with
`User.fromJson()`.

The users are then split into two lists:

- `pendingUsers`: users where `isApproved` is false and `role` is not `moderator`
- `approvedUsers`: users where `isApproved` is true and `role` is not `moderator`

Role comparisons are case-insensitive because the role is converted to
lowercase before checking it.

### User Interface

The page renders a Scaffold with:

- An indigo AppBar titled `Moderator Approval Queue`
- A pending-approvals section with an orange pending icon
- An approved-players section with a green verified-user icon
- A count beside each section heading

Each pending user appears in a card showing their username, identity, and role,
with an `Approve` button. Each approved user appears in a green-tinted card
showing their username and identity, with a `Revoke` button.

### Empty, Loading, and Error States

- While the users stream is loading, the page displays a centered progress indicator.
- If the stream reports an error, the page displays the error text.
- If there are no pending users, the page displays a no-pending-approvals card.
- If there are no approved users, the page displays a no-approved-players card.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) converts Firestore user documents into application user objects.
- Cloud Firestore provides the real-time `users` collection stream and stores approval changes.

### Implementation Notes

- Approval changes are written directly with the Firebase client rather than through `JsonStorageService`.
- The page does not use a confirmation dialog before approving or revoking a user.
- The `mounted` check prevents snackbar updates after the page has been removed from the widget tree.
- The displayed identity is converted to uppercase for the queue subtitles, but the stored user data is not modified by the page.

--------------------

## `navigatable_management_cards.dart`

### Overview

`navigatable_management_cards.dart` contains three dashboard cards that open
management actions in modal bottom sheets or confirmation dialogs:

- `ApprovalQueueCardPreview`: reviews pending moderator registrations
- `PlayerAccessCardPreview`: terminates or reactivates player access
- `SuperAdminDangerZoneCard`: lets the super admin clear user and game data

The file is a collection of navigation and management widgets rather than one
single page. Each card receives the user data it needs from its parent and
delegates database changes to `JsonStorageService`.

### `ApprovalQueueCardPreview`

This stateless widget receives:

- `moderatorList`: the list of moderator registration records

Its summary card displays the number of users whose `isApproved` value is false.
Tapping the card opens a modal bottom sheet that is 60% of the screen height.

The sheet:

- Shows pending moderator registrations
- Displays each moderator's username
- Provides an `Approve` button
- Shows an empty-state message when there are no pending requests
- Includes a close button

Approving a moderator calls
`JsonStorageService.approveModerator(mod.id)`. After the update succeeds, the
sheet closes and a green snackbar confirms the approval.

### `PlayerAccessCardPreview`

This stateless widget receives:

- `playerList`: the registered players whose access can be managed

Its summary card displays the total number of registered players. Tapping it
opens a modal bottom sheet that is 70% of the screen height.

Each player row displays:

- The player's username
- Their in-game identity in uppercase
- An active or terminated status
- A status-dependent action button

Active players have a `Terminate` button, which calls
`JsonStorageService.softDeleteUser(player.id)`. Terminated players have a
`Reactivate` button, which calls `JsonStorageService.reactivateUser(player.id)`.
After either operation succeeds, the sheet closes and a snackbar reports the
result.

### `SuperAdminDangerZoneCard`

This stateful widget receives:

- `currentUser`: the user whose permissions determine whether the card is shown

The card renders nothing when `currentUser.role` is not exactly `superadmin`.
For an authorized user, it displays a red danger-zone card with a button to
clear all user data and active game progress.

`_confirmAndClearData()`:

1. Opens a confirmation dialog warning that all users, players, and moderators will be deleted.
2. Explains that the question bank and current super-admin account will remain.
3. Stops if the user cancels the dialog.
4. Sets `_isClearing` to true and disables the purge button.
5. Calls `JsonStorageService.clearAllUserDataExceptQuestions()` with the current super-admin ID.
6. Shows a success or error snackbar.
7. Clears the loading state when the operation finishes.

The underlying storage service preserves the active super-admin account and the
question bank, while resetting the shared game state.

### User Interface

The file uses Material components including:

- Cards and list tiles for dashboard summaries
- Modal bottom sheets for detailed management lists
- Alert dialogs for destructive-action confirmation
- Snackbars for operation results
- Loading indicators while the danger-zone purge is running

The cards use distinct visual cues: orange for pending moderator approvals, blue
for player access management, and red for the super-admin danger zone.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides user identity, role, approval, and termination data.
- [JSON storage service](../../services/json_storage_service.dart) approves moderators, changes player access, and clears user data.
- Flutter Material widgets provide the cards, dialogs, bottom sheets, buttons, and feedback elements.

### Implementation Notes

- The cards do not listen to Firestore directly; they use the lists supplied by their parent widget.
- The approval and player-access sheets close after successful actions, so the parent must rebuild with updated user data for the summary counts and statuses to reflect the changes.
- The danger-zone visibility check is case-sensitive and requires the exact role string `superadmin`.
- The destructive reset is protected by a confirmation dialog and a disabled button while the operation is in progress.

---------------------

## `phase_banner.dart`

### Overview

`phase_banner.dart` defines `PhaseBanner`, a Flutter `StatelessWidget` that
displays the current game phase as a live dashboard banner.

The banner presents:

- The current phase and round number
- A phase-specific icon and color
- A `LIVE` status indicator
- The moderator's current announcement

### Data Source

The widget listens to the shared game state through
`JsonStorageService.streamGameState()`. It rebuilds automatically whenever the
game-state document changes.

The following fields are read from the streamed state:

- `phase`: the current phase name, converted to lowercase
- `round`: the current round number, defaulting to `1`
- `announcement`: the message shown below the phase title

If no state has been received yet, the widget uses an empty map and displays
the default values.

### Phase Styling

The phase name is mapped to a visual style with a `switch` statement:

| Phase | Color | Icon | Title format |
| --- | --- | --- | --- |
| `night` | Dark indigo | Night/sleep icon | `NIGHT PHASE (Round n)` |
| `voting` | Deep orange | Voting icon | `VOTING PHASE (Round n)` |
| `day` | Amber | Sun icon | `DAY PHASE (Round n)` |
| Any other value | Amber | Sun icon | Day phase title |

The phase text is normalized to lowercase before the comparison, so values
such as `NIGHT` are treated as `night`.

### User Interface

The widget renders a full-width rounded `Container` containing:

- A phase icon
- A bold phase title
- A `LIVE` badge
- An announcement panel with a campaign icon

The banner uses the selected phase color for its background and a matching
semi-transparent shadow. The announcement is displayed in an expanded area so
longer moderator messages can use the available width.

### Default and Fallback Behavior

- Missing `phase` values default to `day`.
- Missing `round` values default to `1`.
- Missing `announcement` values display `Awaiting moderator updates...`.
- Unrecognized phase values use the same styling as the day phase.

### Data and Service Dependencies

- [JSON storage service](../../services/json_storage_service.dart) provides the real-time game-state stream.
- Flutter Material widgets provide the container, icons, text, colors, and layout components.

### Implementation Notes

- `PhaseBanner` has no local state; the Firestore-backed stream is its source of truth.
- The banner currently recognizes only `night`, `voting`, and `day` phase names. More detailed phase values such as `killerPhase` or `villagersPhase` fall through to the day styling.
- The widget is display-only and does not change the game state.

---------------------

## `player_access_management.dart`

### Overview

`player_access_management.dart` defines `PlayerAccessManagementScreen`, a
Flutter `StatefulWidget` screen for viewing and changing player access status.

The screen:

- Lists registered players in real time
- Shows each player's identity, access status, and life status
- Revokes access for active players
- Re-grants access to terminated players

### Local State

The state object maintains `_loadingUserIds`, a set of user IDs currently being
updated. This allows one row to show a loading indicator without blocking the
other player rows.

### Identity Chips

`_buildIdentityChip()` converts a player's identity into a colored badge:

| Identity | Badge color |
| --- | --- |
| `killer` | Dark red |
| `healer` | Green |
| `detective` | Blue |
| `villager` | Orange |
| Any other value | Grey with `UNASSIGNED` label |

Identity matching is case-insensitive. Known identities are shown in uppercase
with white text; unknown or empty identities use a dark text color for contrast
against the grey badge.

### Toggling Player Access

`_toggleAccess()` updates one player at a time:

1. Adds the user's ID to `_loadingUserIds`.
2. Calls `JsonStorageService.reactivateUser()` when the player is terminated.
3. Calls `JsonStorageService.softDeleteUser()` when the player is active.
4. Displays an error snackbar if the operation fails.
5. Removes the user's ID from `_loadingUserIds` when the operation finishes.

The corresponding button changes between `Revoke Access` and `Re-grant Access`
based on `user.isTerminated`.

### User Data Stream and Filtering

The `build()` method listens to all users through
`JsonStorageService.streamAllUsers()`.

Only users whose role is exactly `mafia` are displayed. Super-admin and
moderator accounts are excluded by this filter.

The screen handles the stream states as follows:

- Shows a centered progress indicator while the initial data is loading.
- Shows an error message when the stream fails.
- Shows `No registered players found.` when no matching players exist.
- Displays the filtered users in a separated scrolling list when data is available.

### User Interface

The screen renders a Scaffold with:

- An AppBar titled `Player Access Management`
- A list row for each matching player
- A status avatar showing active or terminated access
- The player's username and identity badge
- A subtitle containing role, access status, and life status
- An access action button or row-specific loading indicator

The life status is informational only. This screen changes `isTerminated` through
the access service; it does not change the player's `isAlive` value.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides identity, role, access, and alive-status fields.
- [JSON storage service](../../services/json_storage_service.dart) streams all users and persists access changes.
- Flutter Material widgets provide the Scaffold, list, badges, buttons, and feedback components.

### Implementation Notes

- Access changes are reflected through the real-time user stream after the storage update completes.
- Each player row has independent loading state because `_loadingUserIds` stores IDs rather than a single global loading flag.
- The screen does not show a confirmation dialog before revoking or re-granting access.
- Successful updates do not show a success snackbar; the changed row state is supplied by the user stream.

---------------------

## `player_status_grid.dart`

### Overview

`player_status_grid.dart` defines `PlayerStatusGrid`, a Flutter
`StatelessWidget` that displays a real-time roster of town players and their
current status.

The card shows:

- Registered town members
- Whether each player is alive or eliminated
- A visual distinction for the current user
- A real-time status indicator

### Input

The widget receives one required value:

- `currentUser`: the logged-in user, used to identify and highlight the current player's roster entry

### Identity Colors

`_getIdentityColor()` maps identities to colors for the current user's identity
label:

| Identity | Color |
| --- | --- |
| `killer` | Red |
| `healer` | Green |
| `detective` | Blue |
| `villager` | Orange |
| Any other value | Grey |

Identity matching is case-insensitive.

### User Data Stream and Filtering

The widget listens to all users through
`JsonStorageService.streamAllUsers()` and rebuilds when the stream changes.

Only users whose role is exactly `mafia` are included in the roster. Other
accounts, including moderators and super admins, are excluded.

The stream is handled as follows:

- Shows a progress indicator during the initial load when no data is available.
- Shows `No active town members.` when the filtered list is empty.
- Displays the matching players in the roster grid when data is available.

### Roster Grid

The players are rendered with `GridView.builder` using a non-scrolling grid so
the card can be placed inside a larger dashboard scroll view. The grid uses:

- A maximum item width of 220 pixels
- An item height of 85 pixels
- 12-pixel horizontal and vertical spacing

Each player tile contains:

- A status avatar with a person or close icon
- The player's username
- A status label or identity label

### Player Tile States

Living players use green status colors. Eliminated players use red colors, and
their usernames are greyed out with a line through the text.

The current user's tile is highlighted with an indigo background and a thicker
indigo border. It appends `(You)` to the username and shows the current user's
identity instead of the general `ALIVE` or `ELIMINATED` label.

Other players show:

- `ALIVE` when `player.isAlive` is true
- `ELIMINATED` when `player.isAlive` is false

Long usernames are limited to one line and truncated with an ellipsis so the
fixed-size tile remains stable.

### User Interface

The widget renders a Material `Card` containing:

- A teal people icon
- A `Town Roster & Status` heading
- A `Real-time` badge
- A divider
- The player status grid or its loading/empty state

The card is display-only and does not provide controls for changing player
status.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides player identity, role, ID,
	username, and alive-status data.
- [JSON storage service](../../services/json_storage_service.dart) provides the real-time user stream.
- Flutter Material widgets provide the card, grid, avatars, icons, and text styling.

### Implementation Notes

- The role filter is case-sensitive and requires the exact value `mafia`.
- The widget reads live user data but does not modify it.
- The current user's identity label comes from `currentUser.identity`, while other players are represented only by their alive or eliminated status.

---------------------

## `quiz_card.dart`

### Overview

`quiz_card.dart` defines `QuizCard`, a Flutter `StatefulWidget` that displays and
submits the healer rescue quiz for the current user.

The widget:

- Reads the active quiz challenge from shared game state
- Shows the current announcement and night/day context
- Restricts answer submission to living healers
- Records the answer and correctness in Firebase
- Displays success or error feedback to the user

### Input and Local State

The widget receives one required value:

- `currentUser`: the user who may observe or answer the quiz

The state object stores:

- `_answerController`: controls the free-text answer field
- `_isSubmitting`: disables input and submission while Firebase is processing
- `_feedbackMessage`: the current validation, success, or error message
- `_isCorrect`: determines the feedback color and icon

The text controller is disposed when the widget is removed from the tree.

### Reading Game State

The `build()` method listens to
`JsonStorageService.streamGameState()` and reads:

- `isNight`: determines the announcement card's night/day styling
- `announcement`: the message displayed above the quiz content
- `activeQuestion`: the current healer challenge

The active question supports several data formats:

- A map using `question`, `text`, or `title` for the question text
- A map using `correctAnswer` or `answer` for the expected answer
- A plain string, treated as the question text without a correct answer

When no question text is available, the card displays a waiting message for the
moderator or killer to transmit the challenge.

### User Eligibility

The card handles users in this order:

1. Eliminated users receive a disabled observation message and cannot answer.
2. Living non-healers receive a message explaining that the quiz is reserved for healers.
3. Living users whose identity is `healer` receive the rescue quiz form.

Identity matching for healer access is case-insensitive.

### Submitting an Answer

`_submitAnswer()` performs the following steps:

1. Trims the answer from the text field.
2. Shows a validation message if the answer is empty.
3. Marks the card as submitting and clears previous feedback.
4. Compares the submitted answer with `correctAnswer` without regard to letter casing.
5. Stores the result in the Firestore document `game_state/current/healer_answers/{currentUser.id}`.
6. Records the healer ID, healer name, submitted answer, correctness, and a Firebase server timestamp.
7. Shows success or failure feedback and clears the answer field after a successful write.

The answer can be submitted from either the text field's submit action or the
`Submit Rescue Answer` button. The button and text field are disabled while the
submission is in progress.

### Rescue Rules Displayed by the Card

The healer view communicates two important rules:

- Every active healer must answer correctly.
- The answer must be submitted within 30 seconds to save the target.

The card labels this requirement as `UNANIMOUS REQ`. The moderator later uses
the stored healer answers when resolving the round.

### User Interface

The widget displays:

- A night/day announcement banner with a sleep or sun icon
- A non-healer information card when appropriate
- A healer rescue challenge card
- An active question panel
- A free-text answer field
- Animated success or error feedback
- A teal submission button with a progress indicator

The question card uses teal, amber, and indigo Material styling to distinguish
the healer action, strict rescue rule, and active question.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides the current user's ID, name, identity, and alive status.
- [JSON storage service](../../services/json_storage_service.dart) provides the real-time game-state stream.
- Cloud Firestore stores healer answers in the `healer_answers` subcollection.
- Flutter Material widgets provide the form, cards, feedback, and controls.

### Implementation Notes

- Correctness is calculated on the client by comparing lowercase strings; the submitted answer is trimmed, but the correct-answer value is not trimmed.
- Each healer writes to a document named with their user ID, so another submission from the same healer replaces their previous answer.
- The card does not select a protection target; target selection is handled by the dedicated healer action interface.
- The widget is display and submission focused; it does not advance the game phase or modify player survival directly.

---------------------

## `role_action_card.dart`

### Overview

`role_action_card.dart` defines `RoleActionCard`, a Flutter `StatefulWidget`
that routes the current user to the action interface for their in-game role.

It supports three role paths:

- Healers are shown `HealerActionCard` during `healerPhase`.
- Killers are shown `KillerActionCard` during `killerPhase`.
- Detectives receive an investigation form during `detectivePhase`.

### Input and Local State

The widget receives one required value:

- `currentUser`: the logged-in player whose identity determines the action card

The state object stores:

- `_selectedPlayerId`: the detective's selected investigation target
- `_isProcessing`: disables the investigation button while processing
- `_actionFeedback`: the current action or investigation message
- `_isTargetKiller`: stores the detective result when the target is checked

### Live Data Sources

The `build()` method listens to two data sources:

- `JsonStorageService.streamGameState()` for the current phase
- The Firestore `users` collection for the latest player list

Every user document is converted into a `User` object before being passed to a
role-specific card or used to build the detective target list.

### Healer and Killer Routing

When the current user's identity is `healer`:

- During `healerPhase`, the widget returns `HealerActionCard` with the current user and all users as possible players.
- During any other phase, it shows a waiting card explaining that the healer phase is inactive.

When the current user's identity is `killer`:

- During `killerPhase`, the widget returns `KillerActionCard` with the current user and all users as possible players.
- During any other phase, it shows a waiting card explaining that the killer phase is inactive.

Identity comparisons are case-insensitive.

### Detective Investigation

The detective interface is shown only when the current user's identity is
`detective` and the phase is `detectivePhase`.

Eligible investigation targets:

- Cannot be the current detective
- Cannot be terminated
- Must still be alive

`_executeRoleAction()` requires a target, then checks whether the target is a
killer by comparing both their in-game identity and permission role. The result
is displayed in feedback that uses red styling for a killer and green styling
for a non-killer.

### Action Processing

`_executeRoleAction()`:

1. Validates that a target has been selected.
2. Sets the processing state and clears previous feedback.
3. Waits briefly to simulate investigation processing.
4. Determines the target's killer status for detectives.
5. Displays the action or investigation result.
6. Clears the processing state when complete.

The method does not write the investigation result to Firestore. It currently
provides an in-memory result for the active user interface.

### User Interface

The detective view contains:

- An indigo investigation card
- A search icon and investigation heading
- A dropdown of eligible target players
- A result panel after investigation
- An investigation button with a loading indicator

Changing the selected target clears the previous result. If the user is not a
healer, killer, or active detective, the widget returns an empty box and shows
no role action interface.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides player identities, roles, IDs, and alive or terminated status.
- [Healer action card](healer_action_card.dart) handles healer quiz responses.
- [Killer action card](killer_action_card.dart) handles killer target and quiz selection.
- [JSON storage service](../../services/json_storage_service.dart) provides the live game-state stream.
- Cloud Firestore provides the live user collection.

### Implementation Notes

- This widget coordinates role-specific UI but does not itself advance the game phase.
- The detective result is calculated locally and is not persisted.
- Inactive healer and killer roles receive explicit waiting messages, while inactive or unsupported roles receive no widget through `SizedBox.shrink()`.
- The users stream is read even when the current role ultimately renders a waiting card or empty widget.

---------------------

## `user_profile_header.dart`

### Overview

`user_profile_header.dart` defines `UserProfileHeader`, a Flutter
`StatelessWidget` that displays a welcome message and the current user's role or
in-game identity at the top of a dashboard.

The header presents:

- A role-appropriate icon
- A personalized welcome message
- The displayed in-game identity
- An anti-cheat warning for mafia-role users

### Input

The widget receives one required value:

- `user`: the profile whose name, permission role, and in-game identity are displayed

### Role-Based Display Logic

The widget checks the user's permission role:

- `superadmin` uses an admin-panel icon.
- `moderator` uses a security icon.
- Any other role uses a game controller icon.

For super admins and moderators, the displayed identity is replaced with
`GOD`. Other users see their in-game identity converted to uppercase.

Role comparisons are case-sensitive and require the exact role strings shown
above.

### Anti-Cheat Notice

Users whose role is exactly `mafia` receive a shield chip with the message:
`Anti-Cheat Active: Do not leave or switch tabs!`

The chip is not shown for super admins, moderators, or users with other roles.

### User Interface

The widget returns a vertically arranged `Column` containing:

- A 72-pixel role icon colored with the theme's primary color
- A `Welcome back, {username}!` greeting
- An `In-Game Identity: {identity}` label in bold purple text
- An optional green shield chip for mafia users

Spacing is added between each element to keep the profile information visually
separated.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides the username, permission role, and in-game identity.
- Flutter Material widgets provide the icons, text, chip, theme colors, and layout.

### Implementation Notes

- `UserProfileHeader` has no local state and does not listen to Firestore.
- It does not modify the user or game state; it only renders the supplied `User` object.
- The displayed `GOD` identity is a presentation choice and does not change the user's stored identity.

---------------------

## `villager_action_card.dart`

### Overview

`villager_action_card.dart` defines `VillagerActionCard`, a Flutter
`StatefulWidget` that provides the town discussion and accusation-voting
interface for villagers.

The card allows a player to:

- Select another eligible player to accuse
- Submit one accusation vote during the discussion/day phase
- See whether voting is open or locked
- View their previously recorded vote when available

### Inputs and Local State

The widget receives:

- `currentUser`: the player casting the accusation vote
- `players`: the list of users who can potentially be accused

The state object stores:

- `_selectedAccusedId`: the currently selected accusation target
- `_isSubmitting`: disables the vote button while the Firebase write is active

The `_validAccusationTargets` getter excludes the current user, terminated
players, and eliminated players.

### Determining Whether Voting Is Open

The `build()` method listens to `JsonStorageService.streamGameState()` and reads:

- `isNight`: whether the game is currently in the night state
- `phase`: the current phase name
- `discussionPhaseActive`: an explicit flag that can open discussion voting

Voting is considered active when any of these conditions is true:

- `isNight` is false
- The phase contains `day`
- The phase contains `discussion`
- `discussionPhaseActive` is true

Otherwise, the card displays a locked message explaining that accusation voting
is disabled during the night phase.

### Reading Existing Votes

The card also listens to the Firestore subcollection
`game_state/current/day_votes`.

It finds the current user's vote by looking for a document whose ID matches
`currentUser.id`. If one exists, its `accusedUserId` is used to populate the
dropdown as the current vote unless a newer local selection exists.

### Submitting an Accusation

`_submitDayVote()`:

1. Requires an accusation target to be selected.
2. Sets `_isSubmitting` to true.
3. Writes the vote to `game_state/current/day_votes/{currentUser.id}`.
4. Stores the voter ID, voter name, accused user ID, and a Firebase server timestamp.
5. Shows an amber success snackbar after a successful write.
6. Shows a red error snackbar if the write fails.
7. Clears the submitting state when the operation finishes.

Because the document ID is the voter's ID, submitting again replaces that
player's previous accusation rather than creating a duplicate vote.

### User Interface

The card renders an orange-themed Material `Card` containing:

- A gavel icon and `Town Discussion & Trial Vote` heading
- A `VOTING OPEN` or `LOCKED` status badge
- A locked-state explanation during inactive periods
- A suspect-selection dropdown during active discussion
- A `Cast Accusation Vote` button with a loading indicator

The dropdown shows only valid accusation targets. The button is disabled while a
vote is being submitted or when no local target has been selected.

### Data and Service Dependencies

- [User model](../../models/user_model.dart) provides player IDs, names, alive, and terminated status.
- [JSON storage service](../../services/json_storage_service.dart) provides the real-time game-state stream.
- Cloud Firestore stores accusation votes in the `day_votes` subcollection.
- Flutter Material widgets provide the card, dropdown, status badge, and button.

### Implementation Notes

- The card does not resolve the winning accusation or eliminate a player; it only records the individual vote.
- Existing votes are read from Firestore and displayed, but the submit button's enabled state depends on `_selectedAccusedId` being set locally.
- The vote window is controlled by a combination of `isNight`, phase-name matching, and `discussionPhaseActive`.

---------------------

