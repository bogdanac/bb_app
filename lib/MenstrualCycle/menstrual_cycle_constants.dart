class MenstrualCycleConstants {
  // Phase Names - Edit these strings to change them everywhere at once
  static const String menstrualPhase = "Menstrual Phase";
  static const String follicularPhase = "Follicular Phase"; 
  static const String ovulationPhase = "Ovulation Window"; // Changed to Window as requested
  static const String earlyLutealPhase = "Early Luteal Phase";
  static const String lateLutealPhase = "Late Luteal Phase";
  
  // Special day names
  static const String menstrualStartDay = "Menstrual Start Day";
  static const String ovulationPeakDay = "Ovulation Peak Day";
  
  // Phase descriptions with day ranges
  static const String menstrualPhaseDesc = "Menstrual Phase (Days 1-5)";
  static const String follicularPhaseDesc = "Follicular Phase (Days 6-11)";
  static const String ovulationPhaseDesc = "Ovulation Window (Days 12-16)"; // Changed to Window
  static const String earlyLutealPhaseDesc = "Early Luteal Phase (Days 17-21)";
  static const String lateLutealPhaseDesc = "Late Luteal Phase (Days 22-28)";
  
  // Special day descriptions
  static const String menstrualStartDayDesc = "Menstrual Start Day (Day 1 only) - Shows for 2 days";
  static const String ovulationPeakDayDesc = "Ovulation Peak Day (Day 14 only) - Shows for 2 days";
  
  // Task display names with emojis
  static const String menstrualPhaseTask = "During Menstrual Phase (Days 1-5) 🩸";
  static const String follicularPhaseTask = "During Follicular Phase (Days 6-11) 🌱";
  static const String ovulationPhaseTask = "During Ovulation Window (Days 12-16) 🥚"; // Changed to Window
  static const String earlyLutealPhaseTask = "During Early Luteal Phase (Days 17-21) 🌙";
  static const String lateLutealPhaseTask = "During Late Luteal Phase (Days 22-28) 🌙";
  
  // Special day task display names
  static const String menstrualStartDayTask = "On Menstrual Start Day (Day 1 only) 🩸";
  static const String ovulationPeakDayTask = "On Ovulation Peak Day (Day 14 only) 🥚";
  
  // Short names for task cards
  static const String menstrualPhaseShort = "Menstrual";
  static const String follicularPhaseShort = "Follicular";
  static const String ovulationPhaseShort = "Ovulation";
  static const String earlyLutealPhaseShort = "Early Luteal";
  static const String lateLutealPhaseShort = "Late Luteal";
  static const String menstrualStartDayShort = "Menstrual Day 1";
  static const String ovulationPeakDayShort = "Ovulation Day 14";
  
  // Default calories for each phase
  static const Map<String, int> defaultPhaseCalories = {
    menstrualPhase: 1800,
    follicularPhase: 2000,
    ovulationPhase: 2200,
    earlyLutealPhase: 2100,
    lateLutealPhase: 1900,
  };
  
  // List of all phases (for iteration)
  static const List<String> allPhases = [
    menstrualPhase,
    follicularPhase,
    ovulationPhase,
    earlyLutealPhase,
    lateLutealPhase,
  ];
  
  // Day ranges for each phase
  static const Map<String, List<int>> phaseRanges = {
    menstrualPhase: [1, 5],        // Days 1-5
    follicularPhase: [6, 11],      // Days 6-11  
    ovulationPhase: [12, 16],      // Days 12-16
    earlyLutealPhase: [17, 21],    // Days 17-21
    lateLutealPhase: [22, 28],     // Days 22-28
  };
  
  // Specific days for special options
  static const int menstrualStartDayNumber = 1;
  static const int ovulationPeakDayNumber = 14;
}