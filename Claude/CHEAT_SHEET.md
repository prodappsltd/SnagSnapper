# 🎯 SnagSnapper Project Cheat Sheet
**Your Quick Reference Guide for Project Management**

---

## 📍 Quick Navigation

```
Claude/
├── 00-CORE/           → Requirements & Rules (Don't change)
├── 01-PLANNING/       → Roadmap, Decisions, This Cheat Sheet
├── 02-MODULES/        → All module work
├── 03-TESTING/        → Test results & bugs
└── 04-RELEASES/       → Release notes & deployment
```

---

## 🗣️ Essential Prompts for Different Scenarios

### 📅 Daily/Weekly Status Checks

#### Monday - Planning Check
```
"Show me this week's plan from ROADMAP.md and any pending decisions from DECISIONS_LOG.md"
```

#### Wednesday - Progress Check  
```
"What's the current progress on [Profile]? Show me the PROGRESS.md and any blockers also any pending Decisions from Decisions_log.md"
```

#### Friday - Weekly Review
```
"Give me the weekly summary: what was completed, what's blocked, and what needs my approval"
```

---

### 🚀 Starting New Work

#### Before Starting a New Module
```
"Create a plan for [Module Name] module following our PROJECT_EXECUTION_PLAN. Include user stories, timeline, and success criteria for my approval"
```

#### Design Review Request
```
"Show me the design for [Feature Name]. Include database schema, UI mockups, and integration points"
```

#### Technical Decision Needed
```
"I need to decide on [describe issue]. Add this to DECISIONS_LOG.md with options and your recommendation"
```

---

### ✅ Approval Checkpoints

#### Module Planning Approval
```
"Is the [Module Name] plan ready for my approval? Show me the plan document and key decisions needed"
```

#### Module Completion Approval
```
"Show me evidence that [Module Name] is complete. Include test results, screenshots, and any outstanding issues"
```

#### Architecture Change Approval
```
"Explain the proposed architecture change for [Component]. What's the impact on timeline and other modules?"
```

---

### 🐛 Problem Resolution

#### Bug Report
```
"Add bug: [describe issue] to BUG_TRACKER.md and tell me the severity and impact"
```

#### Blocker Discussion
```
"I'm blocked by [describe issue]. What are my options and what do you recommend?"
```

#### Performance Issue
```
"The app is slow when [describe scenario]. Show me PERFORMANCE_METRICS.md and optimization options"
```

---

### 📊 Comprehensive Reviews

#### Full Project Status
```
"Give me the complete project status: overall progress, current sprint, blockers, and upcoming decisions needed"
```

#### Module Deep Dive
```
"Show me everything about [Module Name]: plan, progress, tests, bugs, and completion status"
```

#### Quality Check
```
"Run a quality check on [Module Name]: test coverage, bug count, performance metrics, and code review status"
```

---

### 🎯 Specific Information Queries

#### Documentation
```
"Show me the documentation structure and where to find [specific document]"
```

#### Test Results
```
"What's the test status for [Module/Feature]? Show passing/failing tests and coverage"
```

#### PRD Compliance
```
"Is [Feature Name] compliant with the PRD? Show me the requirements and implementation status"
```

#### Timeline
```
"When will [Module/Feature] be complete? Show me the roadmap and any risks"
```

---

### 🔄 Process Management

#### Update Documentation
```
"Update [Document Name] with [new information]"
```

#### Create New Document
```
"Create a [Document Type] for [Purpose] following our documentation standards"
```

#### Archive Old Docs
```
"What documentation can be archived? Show me redundant or outdated files"
```

---

## 📋 Standard Operating Procedures

### When You Want To...

#### ✅ Approve Something
```
"Approve decision #X in DECISIONS_LOG.md with rationale: [your reasoning]"
```

#### ❌ Reject Something
```
"Reject the proposal for [Feature/Change] because [reason]. What are the alternatives?"
```

#### 🔄 Change Priority
```
"Change priority: Move [Module B] before [Module A]. Update ROADMAP.md and explain impact"
```

#### ⏸️ Pause Work
```
"Pause work on [Module/Feature] because [reason]. Update status and document in DECISIONS_LOG.md"
```

#### ▶️ Resume Work
```
"Resume work on [Module/Feature]. Show me where we left off and next steps"
```

---

## 🚦 Status Indicators to Look For

### Good (Green) 💚
- "All tests passing"
- "On schedule"
- "No blockers"
- "Within performance targets"

### Warning (Yellow) 💛
- "Some tests failing"
- "Minor delay expected"
- "Non-critical bugs found"
- "Approaching limits"

### Critical (Red) ❤️
- "Blocked"
- "Critical bug"
- "Major delay"
- "PRD deviation"
- "Security issue"

---

## 📝 Quick Templates

### Make a Decision
```
"I decide to [decision]. Update DECISIONS_LOG.md and proceed with implementation"
```

### Request Information
```
"Show me [specific information] from [document name] and summarize the key points"
```

### Give Feedback
```
"Feedback on [Feature/Module]: [your feedback]. How should we proceed?"
```

### Set Deadline
```
"Set deadline for [Task/Module] to [Date]. Update ROADMAP.md and identify any risks"
```

---

## 🔍 Compliance Checks

### Ensure Quality
```
"Verify [Module/Feature] meets all quality criteria from PROJECT_RULES.md"
```

### Check PRD Alignment
```
"Confirm [Feature] aligns with PRD section [X.X]. Show me any deviations"
```

### Test Coverage
```
"What's the test coverage for [Module]? Show me what's not tested"
```

### Performance Check
```
"Does [Feature] meet performance requirements? Show me the metrics"
```

---

## 📊 Report Requests

### Executive Summary
```
"Give me a one-page executive summary of project status for [stakeholder type]"
```

### Technical Report
```
"Generate a technical report on [Module] including architecture, implementation, and test results"
```

### Bug Report
```
"Show me all bugs for [Module] sorted by severity"
```

### Progress Report
```
"Create a progress report for the last [time period] with achievements and challenges"
```

---

## 🚨 Emergency Situations

### Critical Bug in Production
```
"CRITICAL: [describe bug]. Show me immediate fixes and rollback options"
```

### Data Loss Risk
```
"DATA RISK: [describe situation]. What's our backup status and recovery options?"
```

### Security Issue
```
"SECURITY: [describe issue]. What's the impact and immediate mitigation?"
```

### Major Delay
```
"DELAY: [Module] will be late because [reason]. Show me recovery options and timeline impact"
```

---

## 💡 Pro Tips

1. **Always specify the module** you're asking about
2. **Reference document names** when you want specific info
3. **Use "show me"** to see actual content vs summaries
4. **Say "update"** when you want changes saved
5. **Include "why"** in your decisions for better documentation
6. **Ask for "options"** when you need alternatives
7. **Request "impact"** to understand consequences

---

## 📅 Your Routine Checklist

### Daily (Optional)
- [ ] "Any critical issues or blockers?"
- [ ] "Show me today's planned work"

### Weekly (Recommended)
- [ ] Monday: "Show me this week's plan"
- [ ] Wednesday: "Any decisions needed?"
- [ ] Friday: "Show me weekly progress"

### Per Module
- [ ] Start: "Approve module plan"
- [ ] Middle: "Review progress"
- [ ] End: "Approve completion"

### Monthly
- [ ] "Show me overall project health"
- [ ] "Update roadmap with actuals"
- [ ] "Archive old documentation"

---

## 🎯 Most Important Prompts

### The Three Essential Questions:

1. **"What needs my approval?"**
   - Shows all pending decisions

2. **"What's blocking progress?"**
   - Shows all blockers and options

3. **"Are we on track?"**
   - Shows timeline, quality, and risks

---

## 📞 How to Escalate

If something needs immediate attention:
```
"URGENT: [issue]. This is blocking [what] and needs immediate decision on [what decision]"
```

---

**Remember**: This system is designed to give you control without overwhelming you with details. Use these prompts to get exactly the information you need, when you need it.