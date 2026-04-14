import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/task_model.dart';
import '../models/schedule_analysis.dart';

class AiScheduleService extends ChangeNotifier {
  ScheduleAnalysis? _currentAnalysis;
  bool _isLoading = false;
  String? _errorMessage;

  // FIXED: Removed 'flut' typo from the end of the key
  final String _apiKey = 'AIzaSyC2PrrELopevYzEZ4GeIjFbNm0WhTGW_So';

  ScheduleAnalysis? get currentAnalysis => _currentAnalysis;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> analyzeSchedule(List<TaskModel> tasks) async {
    if (_apiKey.isEmpty || tasks.isEmpty) {
      _errorMessage = tasks.isEmpty ? "No tasks to analyze" : "API Key is missing";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _currentAnalysis = null;
    notifyListeners();

    try {
      // FIXED: Removed 'models/' prefix.
      // The SDK handles the prefix internally. Using just 'gemini-1.5-flash'
      // fixes the "API version v1beta" error.
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      final tasksJson = jsonEncode(tasks.map((t) => t.toJson()).toList());

      final prompt = '''
        You are an expert student scheduling assistant. 
        Analyze the following student tasks provided in JSON format:
        $tasksJson
       
        Identify overlaps or conflicts in timing and suggest a better balanced schedule.
       
        Please provide exactly these 4 sections using markdown headers:
       
        ### Detected Conflicts
        ### Ranked Tasks
        ### Recommended Schedule
        ### Explanation
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        _currentAnalysis = _parseResponse(response.text!);
      } else {
        _errorMessage = "AI returned an empty response.";
      }
    } catch (e) {
      _errorMessage = 'Analysis Failed: $e';
      debugPrint('AI Error Details: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ScheduleAnalysis _parseResponse(String fullText) {
    String conflicts = "None detected.";
    String rankedTasks = "";
    String recommendedSchedule = "";
    String explanation = "";

    // Split by the headers defined in the prompt
    final sections = fullText.split('### ');

    for (var section in sections) {
      final trimmedSection = section.trim();
      if (trimmedSection.startsWith('Detected Conflicts')) {
        conflicts = trimmedSection.replaceFirst('Detected Conflicts', '').trim();
      } else if (trimmedSection.startsWith('Ranked Tasks')) {
        rankedTasks = trimmedSection.replaceFirst('Ranked Tasks', '').trim();
      } else if (trimmedSection.startsWith('Recommended Schedule')) {
        recommendedSchedule = trimmedSection.replaceFirst('Recommended Schedule', '').trim();
      } else if (trimmedSection.startsWith('Explanation')) {
        explanation = trimmedSection.replaceFirst('Explanation', '').trim();
      }
    }

    return ScheduleAnalysis(
      conflicts: conflicts,
      rankedTasks: rankedTasks,
      recommendedSchedule: recommendedSchedule,
      explanation: explanation,
    );
  }

  void clearAnalysis() {
    _currentAnalysis = null;
    _errorMessage = null;
    notifyListeners();
  }
}