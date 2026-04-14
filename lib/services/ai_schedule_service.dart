import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/task_model.dart';
import '../models/schedule_analysis.dart';

class AiScheduleService extends ChangeNotifier{

  ScheduleAnalysis? _currentAnalysis;
  bool _isLoading = false;
  String? _errorMessage;

  final String _apiKey = '';

  ScheduleAnalysis? get currentAnalysis  => _currentAnalysis;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;


  Future<void> analyzeSchedule(List<TaskModel> task) async{

    if(_apiKey.isEmpty || task.isEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try{
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
      final taskJson = jsonEncode(task.map((t) => t.toJson()).toList());
      final prompt = '''
      
      You are an Expert student scheduling assistant. The user has provided the following task for their day in JSON format: $taskJson
      
      Your job is to analyze there tasks, identify any overlaps or conflicts in their start and the end of time and suggest a better balanced schedule.
      consider their urgency, importance, and required energy level.
      
      Please provide exactly 4 sections of markdown text:
      
      1. ### Detected Conflicts
      List any Scheduling conflicts
      2. ### Ranked Tasks
      Rank which tasks need attention first based on the urgency, importance and energy. Provide a brief reason each.
      3. ###  Recommended Schedule
      Provide a revised daily timeline view adjusting the task time.
      4. ### Explanation
      Explain why this Recommendation was made
      
      ''';

      final content = [Content.text(prompt)];

      final response = await model.generateContent(content);

      _currentAnalysis = _parseResponse(response.text ?? '');
    } catch(e) {
      _errorMessage = 'Failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ScheduleAnalysis _parseResponse (String fullText) {
    String conflicts = "",
      rankedTasks = "",
      recommendedSchedule = "",
      explanation = "";

    final sections = fullText.split('### ');

    for (var section in sections){
      if (section.startsWith('Detected Conflicts')) conflicts = section.replaceFirst('Detected Conflicts', '').trim();

      else if (section.startsWith('Ranked Tasks')) rankedTasks = section.replaceFirst('Ranked Tasks', '').trim();

      else if (section.startsWith('Recommended Schedule')) recommendedSchedule = section.replaceFirst('Recommended Schedule', '').trim();

      else if (section.startsWith('Explanation')) explanation = section.replaceFirst('Explanation', '').trim();
    }

    return ScheduleAnalysis(
      conflicts: conflicts,
      rankedTasks: rankedTasks,
      recommendedSchedule: recommendedSchedule,
      explanation: explanation,
    );
  }
}