;; title: participant-confusion-maximizer
;; version: 1.0.0
;; summary: Schedules meetings when key decision-makers are unavailable
;; description: Advanced system for maximizing scheduling conflicts and participant confusion

;; traits
;;

;; token definitions
;;

;; constants
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-MEETING-ID (err u201))
(define-constant ERR-TOO-MANY-PARTICIPANTS (err u202))
(define-constant ERR-INVALID-TIMEZONE (err u203))
(define-constant ERR-MEETING-ALREADY-EXISTS (err u204))
(define-constant ERR-PARTICIPANT-LIMIT-EXCEEDED (err u205))
(define-constant ERR-INVALID-TOPIC (err u206))

(define-constant MAX-PARTICIPANTS-PER-MEETING u50)
(define-constant MAX-TIMEZONE-OFFSET u24)
(define-constant MIN-TOPIC-LENGTH u10)
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-MEETINGS u500)

;; Confusion multiplier factors
(define-constant TIMEZONE-CHAOS-MULTIPLIER u7)
(define-constant STAKEHOLDER-EXCLUSION-FACTOR u5)
(define-constant IRRELEVANT-INCLUSION-FACTOR u3)
(define-constant SCHEDULING-CONFLICT-MULTIPLIER u9)

;; data vars
(define-data-var total-meetings-scheduled uint u0)
(define-data-var total-conflicts-created uint u0)
(define-data-var total-wrong-participants uint u0)
(define-data-var system-chaos-level uint u5)
(define-data-var timezone-confusion-enabled bool true)

;; data maps
(define-map meeting-registry
  { meeting-id: uint }
  {
    topic: (string-ascii 500),
    scheduled-time: uint,
    timezone-offset: int,
    conflict-score: uint,
    participants-count: uint,
    key-stakeholders-excluded: uint,
    irrelevant-participants: uint,
    created-by: principal,
    created-at: uint
  }
)

(define-map participant-assignments
  { meeting-id: uint, participant-index: uint }
  {
    participant: principal,
    relevance-score: uint,
    timezone-offset: int,
    availability-conflict: bool,
    is-key-stakeholder: bool,
    confusion-factor: uint
  }
)

(define-map timezone-chaos-matrix
  { timezone-id: uint }
  {
    timezone-name: (string-ascii 50),
    utc-offset: int,
    chaos-multiplier: uint,
    participant-count: uint
  }
)

(define-map participant-confusion-history
  { participant: principal }
  {
    meetings-invited: uint,
    relevant-meetings: uint,
    timezone-conflicts: uint,
    scheduling-conflicts: uint,
    confusion-score: uint
  }
)

(define-map meeting-conflict-matrix
  { participant: principal, time-slot: uint }
  {
    conflicting-meetings: uint,
    priority-conflicts: uint,
    chaos-contribution: uint
  }
)

;; Initialize timezone chaos matrix
(map-insert timezone-chaos-matrix
  { timezone-id: u1 }
  { timezone-name: "Pacific/Honolulu", utc-offset: -10, chaos-multiplier: u8, participant-count: u0 }
)

(map-insert timezone-chaos-matrix
  { timezone-id: u2 }
  { timezone-name: "America/New_York", utc-offset: -5, chaos-multiplier: u3, participant-count: u0 }
)

(map-insert timezone-chaos-matrix
  { timezone-id: u3 }
  { timezone-name: "Europe/London", utc-offset: 0, chaos-multiplier: u5, participant-count: u0 }
)

(map-insert timezone-chaos-matrix
  { timezone-id: u4 }
  { timezone-name: "Asia/Tokyo", utc-offset: 9, chaos-multiplier: u7, participant-count: u0 }
)

(map-insert timezone-chaos-matrix
  { timezone-id: u5 }
  { timezone-name: "Australia/Sydney", utc-offset: 11, chaos-multiplier: u9, participant-count: u0 }
)

;; public functions
(define-public (create-scheduling-conflict 
  (meeting-id uint) 
  (participants (list 20 principal))
)
  (let (
    (participants-count (len participants))
    (conflict-score (calculate-conflict-potential participants))
    (optimal-chaos-time (find-maximum-conflict-time participants))
  )
    (asserts! (< (var-get total-meetings-scheduled) MAX-MEETINGS) ERR-MEETING-ALREADY-EXISTS)
    (asserts! (<= participants-count MAX-PARTICIPANTS-PER-MEETING) ERR-TOO-MANY-PARTICIPANTS)
    (asserts! (is-none (map-get? meeting-registry { meeting-id: meeting-id })) ERR-MEETING-ALREADY-EXISTS)
    
    (let (
      (chaos-timezone (select-maximum-chaos-timezone))
      (excluded-stakeholders (filter-key-stakeholders participants))
      (final-conflict-score (+ conflict-score (len excluded-stakeholders)))
    )
      (map-insert meeting-registry
        { meeting-id: meeting-id }
        {
          topic: "High-priority strategic alignment session",
          scheduled-time: optimal-chaos-time,
          timezone-offset: chaos-timezone,
          conflict-score: final-conflict-score,
          participants-count: participants-count,
          key-stakeholders-excluded: (len excluded-stakeholders),
          irrelevant-participants: u0,
          created-by: tx-sender,
          created-at: stacks-block-height
        }
      )
      
      (process-participant-assignments meeting-id participants)
      (update-system-stats conflict-score)
      
      (ok true)
    )
  )
)

(define-public (invite-wrong-participants (meeting-topic (string-ascii 500)))
  (let (
    (topic-length (len meeting-topic))
    (meeting-id (+ (var-get total-meetings-scheduled) u1))
    (irrelevant-participants (generate-irrelevant-participants meeting-topic))
    (excluded-stakeholders (generate-key-stakeholders-to-exclude))
  )
    (asserts! (>= topic-length MIN-TOPIC-LENGTH) ERR-INVALID-TOPIC)
    (asserts! (< (var-get total-meetings-scheduled) MAX-MEETINGS) ERR-MEETING-ALREADY-EXISTS)
    
    (let (
      (total-wrong-invitations (+ (len irrelevant-participants) (len excluded-stakeholders)))
      (confusion-multiplier (calculate-participant-confusion-factor meeting-topic))
    )
      (var-set total-wrong-participants 
        (+ (var-get total-wrong-participants) total-wrong-invitations))
      
      (store-wrong-participant-assignments meeting-id irrelevant-participants excluded-stakeholders)
      
      (ok irrelevant-participants)
    )
  )
)

(define-public (maximize-timezone-confusion (participants (list 30 principal)))
  (let (
    (participants-count (len participants))
    (chaos-level (var-get system-chaos-level))
    (optimal-timezone-distribution (distribute-timezone-chaos participants))
  )
    (asserts! (var-get timezone-confusion-enabled) ERR-NOT-AUTHORIZED)
    (asserts! (<= participants-count MAX-PARTICIPANTS-PER-MEETING) ERR-TOO-MANY-PARTICIPANTS)
    
    (let (
      (maximum-inconvenience-time (calculate-worst-meeting-time participants))
      (timezone-chaos-score (fold calculate-timezone-chaos-contribution participants u0))
    )
      (update-timezone-chaos-stats timezone-chaos-score)
      
      (ok (format-timezone-chaos-result maximum-inconvenience-time timezone-chaos-score))
    )
  )
)

(define-public (schedule-maximum-confusion-meeting
  (topic (string-ascii 500))
  (key-stakeholders (list 10 principal))
  (irrelevant-participants (list 20 principal))
)
  (let (
    (meeting-id (+ (var-get total-meetings-scheduled) u1))
    (all-participants (concat key-stakeholders irrelevant-participants))
    (confusion-time (find-maximum-conflict-time all-participants))
  )
    (asserts! (< (var-get total-meetings-scheduled) MAX-MEETINGS) ERR-MEETING-ALREADY-EXISTS)
    
    ;; Schedule when key stakeholders are unavailable
    (let (
      (stakeholder-conflicts (create-stakeholder-conflicts key-stakeholders confusion-time))
      (timezone-chaos (maximize-timezone-distribution all-participants))
      (final-confusion-score (+ stakeholder-conflicts timezone-chaos))
    )
      (map-insert meeting-registry
        { meeting-id: meeting-id }
        {
          topic: topic,
          scheduled-time: confusion-time,
          timezone-offset: (select-maximum-chaos-timezone),
          conflict-score: final-confusion-score,
          participants-count: (len all-participants),
          key-stakeholders-excluded: (len key-stakeholders),
          irrelevant-participants: (len irrelevant-participants),
          created-by: tx-sender,
          created-at: stacks-block-height
        }
      )
      
      (var-set total-meetings-scheduled meeting-id)
      (var-set total-conflicts-created 
        (+ (var-get total-conflicts-created) final-confusion-score))
      
      (ok meeting-id)
    )
  )
)

(define-public (toggle-timezone-confusion)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set timezone-confusion-enabled (not (var-get timezone-confusion-enabled)))
    (ok (var-get timezone-confusion-enabled))
  )
)

(define-public (adjust-system-chaos-level (new-level uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-level u10) ERR-INVALID-TIMEZONE)
    (var-set system-chaos-level new-level)
    (ok new-level)
  )
)

;; read only functions
(define-read-only (get-meeting-details (meeting-id uint))
  (map-get? meeting-registry { meeting-id: meeting-id })
)

(define-read-only (get-participant-assignment (meeting-id uint) (participant-index uint))
  (map-get? participant-assignments 
    { meeting-id: meeting-id, participant-index: participant-index }
  )
)

(define-read-only (get-timezone-chaos-info (timezone-id uint))
  (map-get? timezone-chaos-matrix { timezone-id: timezone-id })
)

(define-read-only (get-participant-confusion-history (participant principal))
  (default-to
    { meetings-invited: u0, relevant-meetings: u0, timezone-conflicts: u0, 
      scheduling-conflicts: u0, confusion-score: u0 }
    (map-get? participant-confusion-history { participant: participant })
  )
)

(define-read-only (get-system-confusion-stats)
  {
    total-meetings: (var-get total-meetings-scheduled),
    total-conflicts: (var-get total-conflicts-created),
    wrong-participants: (var-get total-wrong-participants),
    chaos-level: (var-get system-chaos-level),
    timezone-confusion: (var-get timezone-confusion-enabled),
    average-confusion: (if (> (var-get total-meetings-scheduled) u0)
                        (/ (var-get total-conflicts-created) (var-get total-meetings-scheduled))
                        u0)
  }
)

(define-read-only (calculate-meeting-chaos-score (meeting-id uint))
  (match (map-get? meeting-registry { meeting-id: meeting-id })
    meeting-details
    (let (
      (conflict-score (get conflict-score meeting-details))
      (excluded-stakeholders (get key-stakeholders-excluded meeting-details))
      (irrelevant-count (get irrelevant-participants meeting-details))
      (timezone-chaos (* (abs-value (get timezone-offset meeting-details)) u2))
    )
      (some (+ conflict-score excluded-stakeholders irrelevant-count timezone-chaos))
    )
    none
  )
)

(define-read-only (get-optimal-confusion-time (participants (list 15 principal)))
  (find-maximum-conflict-time participants)
)

;; private functions
(define-private (calculate-conflict-potential (participants (list 20 principal)))
  (let (
    (participant-count (len participants))
    (base-conflict-score (* participant-count SCHEDULING-CONFLICT-MULTIPLIER))
  )
    (+ base-conflict-score (var-get system-chaos-level))
  )
)

(define-private (find-maximum-conflict-time (participants (list 30 principal)))
  ;; Calculate the worst possible meeting time based on participant timezones
  (let (
    (chaos-factor (fold calculate-individual-chaos-contribution participants u0))
    (base-inconvenient-time u13) ;; 1 PM UTC (inconvenient for most timezones)
  )
    (+ base-inconvenient-time (mod chaos-factor u24))
  )
)

(define-private (select-maximum-chaos-timezone)
  ;; Select timezone that maximizes confusion
  (let (
    (random-factor (mod stacks-block-height u5))
  )
    (match (map-get? timezone-chaos-matrix { timezone-id: (+ random-factor u1) })
      timezone-info (get utc-offset timezone-info)
      0
    )
  )
)

(define-private (filter-key-stakeholders (participants (list 20 principal)))
  ;; Simulate excluding key stakeholders (simplified for demo)
  (let (
    (exclusion-count (if (<= (/ (len participants) u3) u5) 
                        (/ (len participants) u3) 
                        u5))
  )
    (list tx-sender) ;; Simplified - would exclude based on business logic
  )
)

(define-private (generate-irrelevant-participants (topic (string-ascii 500)))
  ;; Generate list of irrelevant participants based on topic (simplified for demo)
  (list
    CONTRACT-OWNER ;; Simplified - would be actual irrelevant participants
    tx-sender
    CONTRACT-OWNER
    tx-sender
  )
)

(define-private (generate-key-stakeholders-to-exclude)
  ;; Generate key stakeholders to deliberately exclude (simplified for demo)
  (list
    CONTRACT-OWNER ;; Simplified - would be actual key stakeholders
    tx-sender
  )
)

(define-private (calculate-participant-confusion-factor (topic (string-ascii 500)))
  (let (
    (topic-length (len topic))
    (complexity-indicator (if (> topic-length u100) u3 u1))
  )
    (* complexity-indicator IRRELEVANT-INCLUSION-FACTOR)
  )
)

(define-private (distribute-timezone-chaos (participants (list 30 principal)))
  ;; Distribute participants across maximum chaos timezones
  (let (
    (participant-count (len participants))
    (timezone-distribution-score (* participant-count TIMEZONE-CHAOS-MULTIPLIER))
  )
    timezone-distribution-score
  )
)

(define-private (calculate-worst-meeting-time (participants (list 30 principal)))
  ;; Find the worst possible meeting time for all participants
  (let (
    (participant-count (len participants))
    (inconvenience-factor (+ u2 (mod participant-count u12)))
  )
    (+ u22 inconvenience-factor) ;; Late evening/early morning chaos
  )
)

(define-private (calculate-timezone-chaos-contribution (participant principal) (accumulator uint))
  ;; Calculate how much chaos each participant adds to timezone confusion
  (+ accumulator (+ u1 (mod (hash-principal participant) u5)))
)

(define-private (format-timezone-chaos-result (meeting-time uint) (chaos-score uint))
  (concat 
    "Meeting scheduled at hour " 
    (concat (uint-to-ascii meeting-time) (concat " with chaos score: " (uint-to-ascii chaos-score)))
  )
)

(define-private (calculate-individual-chaos-contribution (participant principal) (acc uint))
  (+ acc (+ u1 (mod (hash-principal participant) u7)))
)

(define-private (process-participant-assignments (meeting-id uint) (participants (list 20 principal)))
  ;; Process and store participant assignments with confusion factors
  (fold store-participant-assignment 
    participants 
    { meeting-id: meeting-id, index: u0, stored: u0 }
  )
)

(define-private (store-participant-assignment 
  (participant principal) 
  (context { meeting-id: uint, index: uint, stored: uint })
)
  (let (
    (meeting-id (get meeting-id context))
    (index (get index context))
    (relevance-score (mod (hash-principal participant) u10))
    (timezone-offset (to-int (mod (hash-principal participant) u24)))
  )
    (map-insert participant-assignments
      { meeting-id: meeting-id, participant-index: index }
      {
        participant: participant,
        relevance-score: relevance-score,
        timezone-offset: timezone-offset,
        availability-conflict: (< relevance-score u3),
        is-key-stakeholder: (< relevance-score u2),
        confusion-factor: (+ relevance-score u1)
      }
    )
    { meeting-id: meeting-id, index: (+ index u1), stored: (+ (get stored context) u1) }
  )
)

(define-private (update-system-stats (conflict-score uint))
  (begin
    (var-set total-meetings-scheduled (+ (var-get total-meetings-scheduled) u1))
    (var-set total-conflicts-created (+ (var-get total-conflicts-created) conflict-score))
  )
)

(define-private (store-wrong-participant-assignments 
  (meeting-id uint) 
  (irrelevant (list 4 principal)) 
  (excluded (list 2 principal))
)
  (begin
    ;; Store irrelevant participant assignments
    (fold store-irrelevant-participant irrelevant { meeting-id: meeting-id, index: u0 })
    ;; Note: excluded participants are deliberately not stored (that's the point!)
    true
  )
)

(define-private (store-irrelevant-participant 
  (participant principal) 
  (context { meeting-id: uint, index: uint })
)
  (let (
    (meeting-id (get meeting-id context))
    (index (get index context))
  )
    (map-insert participant-assignments
      { meeting-id: meeting-id, participant-index: index }
      {
        participant: participant,
        relevance-score: u0, ;; Completely irrelevant
        timezone-offset: (select-maximum-chaos-timezone),
        availability-conflict: true,
        is-key-stakeholder: false,
        confusion-factor: u10 ;; Maximum confusion
      }
    )
    { meeting-id: meeting-id, index: (+ index u1) }
  )
)

(define-private (update-timezone-chaos-stats (chaos-score uint))
  (var-set total-conflicts-created (+ (var-get total-conflicts-created) chaos-score))
)

(define-private (create-stakeholder-conflicts (stakeholders (list 10 principal)) (meeting-time uint))
  ;; Create maximum conflicts for key stakeholders
  (fold create-individual-conflict stakeholders u0)
)

(define-private (create-individual-conflict (stakeholder principal) (acc uint))
  ;; Each stakeholder adds to the conflict score
  (+ acc STAKEHOLDER-EXCLUSION-FACTOR)
)

(define-private (maximize-timezone-distribution (participants (list 30 principal)))
  ;; Calculate maximum timezone distribution chaos
  (fold calculate-timezone-distribution-chaos participants u0)
)

(define-private (calculate-timezone-distribution-chaos (participant principal) (acc uint))
  (+ acc (+ u1 (mod (hash-principal participant) TIMEZONE-CHAOS-MULTIPLIER)))
)

;; Helper functions
(define-private (abs-value (value int))
  (to-uint (if (< value 0) (- value) value))
)

(define-private (hash-principal (p principal))
  ;; Simple hash function for demonstration - simplified approach
  (if (is-eq p CONTRACT-OWNER) u42 u17)
)

(define-private (uint-to-ascii (value uint))
  ;; Simplified conversion for demonstration
  (if (<= value u9) "single-digit" "multi-digit")
)
