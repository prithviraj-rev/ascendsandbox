/******************************************************************************
// Project:         Resource Planning and Revenue Forecasting
// Summary:         Service class that implements business logic and methods for working with Assignments which associate Resources to Projects
// Test Class:      RPRFAssignmentServiceTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 04/29/2024 - created
*******************************************************************************/

public with sharing class RPRFAssignmentService implements Callable
{
    public static Boolean isDailyAssignmentAutomationRan = false;

    private static RPRFAssignmentService instance;

    public class RPRFAssignmentServiceException extends Exception {}

    private Set<String> DAILY_ASSIGNMENT_ADDITIONAL_FIELDS = new Set<String>{
        'Assignment__r.Name', 'Assignment__r.Start_Date__c', 'Assignment__r.End_Date__c', 'Assignment__r.Daily_Max__c', 'Assignment__r.Number_Of_Hours__c', 
        'Assignment__r.Assignment_Hours_Remaining__c', 'Assignment__r.Projects__c', 'Assignment__r.Projects__r.Name', 'Assignment__r.Projects__r.Project_Type__c', 
        'Assignment__r.Projects__r.Project_Lead__r.Resource_User_Record__c', 'Contact__r.Name'
    };

    private Set<String> ASSIGNMENT_ADDITIONAL_FIELDS = new Set<String>{
        'Projects__r.Name', 'Projects__r.Project_Type__c', 'Projects__r.Project_Lead__r.Resource_User_Record__c', 'Resource__r.Name'
    };

	/*********************** STATIC SECTION ***********************/

	public static RPRFAssignmentService getInstance()
	{
		if(instance == null) instance = new RPRFAssignmentService();
		return instance;
	}

	/*********************** PUBLIC SECTION ***********************/

    public SFDC_Assignment__c getAssignment(ID assignmentId) {
        return (SFDC_Assignment__c)SObjectService.getInstance().loadSObject(assignmentId);
    }

    public List<SFDC_Assignment__c> getAssignments(ID resourceId, ID projectId, Date fromDate, Date toDate) {
        List<String> dailyAssignmentsConditions = new List<String>();
        List<String> conditions = new List<String>{'Projects__r.Unforcasted_Project__c = false', 'Inactive__c = false'};
        if(resourceId != null) conditions.add('Resource__c = \'' + resourceId + '\'');
        if(projectId != null) conditions.add('Projects__c = \'' + projectId + '\'');

        if(fromDate != null) {
            if (toDate != null) conditions.add('Start_Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd'));
            dailyAssignmentsConditions.add('Daily_Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd'));
        }

        if(toDate != null) {
            if (fromDate != null) conditions.add('End_Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd'));
            dailyAssignmentsConditions.add('Daily_Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd'));
        }

        Set<String> fields = ASSIGNMENT_ADDITIONAL_FIELDS;
        fields.add('(select ' + String.join(SObjectService.getInstance().getSObjectFields('Daily_Assignment__c'), ',') + ' from Daily_Assignments__r ' + (!dailyAssignmentsConditions.isEmpty() ? 'where ' + String.join(dailyAssignmentsConditions, ' and ') : '') + ')');

        return (List<SFDC_Assignment__c>)SObjectService.getInstance().loadSObjects('SFDC_Assignment__c', String.join(conditions, ' and '), fields, 'Projects__r.Name', null, null);
    }

    public List<SFDC_Timecard__c> getAssignmentsTimecards(List<ID> assignmentsIds, List<String> fields, String conditions) {
        if(fields == null) fields = new List<String>(SObjectService.getInstance().getSObjectFields('SFDC_Timecard__c'));
        String query = 'select ' + String.join(fields, ',') + ' from SFDC_Timecard__c where Assignment__c in :param1';
        if(conditions != null) query += ' and (' + conditions + ')';

        return (List<SFDC_Timecard__c>)SObjectService.getInstance().loadSObjects(query, new List<Object> {assignmentsIds});
    }

    public Map<ID, Map<Date, Decimal>> getAssignmentsActualDates(List<ID> assignmentsIds) {
        return getAssignmentsActualDates(assignmentsIds, null, null);
    }

    public Map<ID, Map<Date, Decimal>> getAssignmentsActualDates(List<ID> assignmentsIds, Date fromDate, Date toDate) {
        Map<ID, Map<Date, Decimal>> result = new Map<ID, Map<Date, Decimal>>();

        String conditions = 'Timesheet_Status__c = \'Approved\' and Type__c = \'Billable\'';
        if(fromDate != null) conditions += ' and Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd');
        if(toDate != null) conditions += ' and Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd');

        for(SFDC_Timecard__c record : getAssignmentsTimecards(assignmentsIds, new List<String>{'Assignment__c', 'Date__c', 'Hours__c'}, conditions)) {
            if(!result.containsKey(record.Assignment__c)) result.put(record.Assignment__c, new Map<Date, Decimal>());
     
            Map<Date, Decimal> actualDates = result.get(record.Assignment__c);
            Decimal value = actualDates.get(record.Date__c);
            if(value == null) value = 0;
            actualDates.put(record.Date__c, value + record.Hours__c);
        }

        return result;
    }

    public List<Daily_Assignment__c> getDailyAssignments(ID assignmentId, Date fromDate, Date toDate) {
        String conditions = 'Assignment__c = \'' + assignmentId + '\'';
        if(fromDate != null) conditions += ' and Daily_Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd');
        if(toDate != null) conditions += ' and Daily_Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd');

        return (List<Daily_Assignment__c>)SObjectService.getInstance().loadSObjects('Daily_Assignment__c', conditions, null);
    }

    public List<Daily_Assignment__c> getDailyAssignments(ID resourceId, ID projectId, Date fromDate, Date toDate) {
        List<String> conditions = new List<String>{'Assignment__r.Projects__r.Name not in (\'' + String.join(RPRFResourceService.DayOffProjects, '\',\'') + '\')'};
        if(resourceId != null) conditions.add('Contact__c = \'' + resourceId + '\'');
        if(projectId != null) conditions.add('Assignment__r.Projects__c = \'' + projectId + '\'');
        if(fromDate != null) conditions.add('Daily_Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd'));
        if(toDate != null) conditions.add('Daily_Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd'));

        return (List<Daily_Assignment__c>)SObjectService.getInstance().loadSObjects('Daily_Assignment__c', String.join(conditions, ' and '), DAILY_ASSIGNMENT_ADDITIONAL_FIELDS, 'Assignment__r.Projects__r.Name', null, null);
    }

    public List<Daily_Assignment__c> getDailyAssignmentsByResource(ID resourceId, Date fromDate, Date toDate) {
        List<String> conditions = new List<String>{'Assignment__r.Projects__r.Name not in (\'' + String.join(RPRFResourceService.DayOffProjects, '\',\'') + '\')'};
        if(resourceId != null) conditions.add('Contact__c = \'' + resourceId + '\'');
        if(fromDate != null) conditions.add('Daily_Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd'));
        if(toDate != null) conditions.add('Daily_Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd'));

        return (List<Daily_Assignment__c>)SObjectService.getInstance().loadSObjects('Daily_Assignment__c', String.join(conditions, ' and '), DAILY_ASSIGNMENT_ADDITIONAL_FIELDS, 'Assignment__r.Projects__r.Name', null, null);
    }

    public List<Daily_Assignment__c> getDailyAssignmentsByProject(ID projectId, Date fromDate, Date toDate) {
        List<String> conditions = new List<String>{'Assignment__r.Projects__r.Name not in (\'' + String.join(RPRFResourceService.DayOffProjects, '\',\'') + '\')'};
        if(projectId != null) conditions.add('Assignment__r.Projects__c = \'' + projectId + '\'');
        if(fromDate != null) conditions.add('Daily_Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd'));
        if(toDate != null) conditions.add('Daily_Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd'));

        return (List<Daily_Assignment__c>)SObjectService.getInstance().loadSObjects('Daily_Assignment__c', String.join(conditions, ' and '), DAILY_ASSIGNMENT_ADDITIONAL_FIELDS, 'Assignment__r.Projects__r.Name', null, null);
    }

    public List<SFDC_Assignment__c> getAssignmentsByResourcesAndDates(Map<ID, Set<Date>> resourcesDates) {
        List<SFDC_Assignment__c> result = new List<SFDC_Assignment__c>();
        if(resourcesDates.isEmpty()) return result;

        Date fromDate, toDate;
        for(Set<Date> resourceDates : resourcesDates.values()) {
            for(Date nextDate : resourceDates) {
                if(fromDate == null || fromDate > nextDate) fromDate = nextDate;
                if(toDate == null || toDate < nextDate) toDate = nextDate;
            }
        }

        if(fromDate == null || toDate == null) return result;

        List<String> conditions = new List<String>{'Projects__r.Unforcasted_Project__c = false', 'Inactive__c = false', 'Resource__c in :param1'};
        conditions.add('Start_Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd'));
        conditions.add('End_Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd'));

        for(SFDC_Assignment__c record  : (List<SFDC_Assignment__c>)SObjectService.getInstance().loadSObjects('SFDC_Assignment__c',  null, String.join(conditions, ' and '), null, null, null, new List<Object> {resourcesDates.keySet()})) {
            Set<Date> resourceDates = resourcesDates.get(record.Resource__c);
            
            fromDate = toDate = null;
            for(Date nextDate : resourceDates) {
                if(fromDate == null || fromDate > nextDate) fromDate = nextDate;
                if(toDate == null || toDate < nextDate) toDate = nextDate;
            }

            if(record.Start_Date__c <= toDate && record.End_Date__c >= fromDate) {
                result.add(record);
            }
        }

        return result;
    }

    public Set<Date> getUnavailabeDatesByResource(ID resourceId, Date fromDate, Date toDate) {
        Set<Date> unavailabeDates = RPRFResourceService.getInstance().getUnavailabeDates(resourceId, fromDate, toDate);
        unavailabeDates.addAll(RPRFUtilities.getWeekends(fromDate, toDate));
        return unavailabeDates;
    }

    public void recalculateDailyAssignments(ID assignmentId, Boolean recalculateActualHours, Boolean recalculateProjectedHours) {
        SFDC_Assignment__c assignment = getAssignment(assignmentId);
        if(assignment == null) return;

        System.Savepoint sp = Database.setSavepoint();
        try 
        {
            try {
                isDailyAssignmentAutomationRan = true;
                clearDailyAssignments(assignment);
            } finally {
                isDailyAssignmentAutomationRan = false;
            }            

            Date fromDate = assignment.Start_Date__c;
            Date toDate = assignment.End_Date__c;
            Set<Date> unavailabeDates = getUnavailabeDatesByResource(assignment.Resource__c, fromDate, toDate);

            Integer numberOfAvailableDays = 0;
            for(Date day = fromDate; day <= toDate; day = day.addDays(1)) {
                if(!unavailabeDates.contains(day)) numberOfAvailableDays++;
            }

            if(numberOfAvailableDays == 0) return;

            List<Daily_Assignment__c> dailyAssignments = (
                assignment.Daily_Max__c > 0 ? 
                    buildDailyAssignmentsByDailyMax(assignment, numberOfAvailableDays, unavailabeDates) :
                    buildDailyAssignmentsByDefault(assignment, numberOfAvailableDays, unavailabeDates)
            );

            insert dailyAssignments;

            if(recalculateActualHours == true) recalculateActualHours(new List<ID>{assignmentId});
            if(recalculateProjectedHours == true) recalculateProjectedHours(new List<ID>{assignmentId});
        }catch(Exception ex) {
            Database.rollback(sp);
            throw ex;
        } 
    }

    public void createResourceDailyAssignments(Map<ID, Set<Date>> resourcesDates) {
        if(resourcesDates.isEmpty()) return;

        Set<Date> dates = new Set<Date>();
        for(Set<Date> resourceDates : resourcesDates.values()) {
            dates.addAll(resourceDates);
        }

        for(Daily_Assignment__c record : [select Contact__c, Daily_Date__c from Daily_Assignment__c where Contact__c in :resourcesDates.keySet() and Daily_Date__c in :dates and Assignment__r.Inactive__c != true and Assignment__r.Projects__r.Name not in :RPRFResourceService.DayOffProjects]) {
            resourcesDates.get(record.Contact__c).remove(record.Daily_Date__c);
        }

        Date minDate, maxDate;
        for(Set<Date> resourceDates : resourcesDates.values()) {
            for(Date resourceDate : resourceDates) {
                if(minDate == null || minDate > resourceDate) minDate = resourceDate;
                if(maxDate == null || maxDate < resourceDate) maxDate = resourceDate;
            }
        }

        Set<Date> weekends = RPRFUtilities.getWeekends(minDate, maxDate);
        Map<ID, Set<Date>> unavailabeDates = RPRFResourceService.getInstance().getUnavailabeDates(resourcesDates.keySet(), minDate, maxDate);

        List<Daily_Assignment__c> dailyAssignments = new List<Daily_Assignment__c>();
        for(SFDC_Assignment__c assignment : [select Resource__c, Start_Date__c, End_Date__c from SFDC_Assignment__c where Resource__c in :resourcesDates.keySet() and Inactive__c != true and Start_Date__c <= :maxDate and End_Date__c >= :minDate and Projects__r.Name not in :RPRFResourceService.DayOffProjects]) {
            for(Date resourceDate : resourcesDates.get(assignment.Resource__c)) {
                if(weekends.contains(resourceDate) || unavailabeDates.get(assignment.Resource__c)?.contains(resourceDate) == true) continue;

                if(resourceDate >= assignment.Start_Date__c && resourceDate <= assignment.End_Date__c) {
                    dailyAssignments.add(new Daily_Assignment__c(
                        Name = 'Assignment for ' + RPRFUtilities.formatDate(resourceDate, 'yyyy-MM-dd'),
                        Assignment__c = assignment.Id,
                        Contact__c = assignment.Resource__c,
                        Daily_Date__c = resourceDate
                    ));
                }
            }
        }

        insert dailyAssignments;
    }

    public void clearDailyAssignments(SFDC_Assignment__c assignment) {
        clearDailyAssignments(assignment, null, null);
    }

    public void clearDailyAssignments(SFDC_Assignment__c assignment, Date fromDate, Date toDate) {
        delete getDailyAssignments(assignment.Id, fromDate, toDate);
    }

    public void clearDailyAssignments(Set<Date> dates) {
        if(dates.isEmpty()) return;
        delete [select Id from Daily_Assignment__c where Daily_Date__c in :dates and Assignment__r.Inactive__c != true and Assignment__r.Projects__r.Name not in :RPRFResourceService.DayOffProjects];
    }

    public void clearDailyAssignments(Map<ID, Set<Date>> resourcesDates) {
        if(resourcesDates.isEmpty()) return;

        Set<Date> dates = new Set<Date>();
        for(Set<Date> resourceDates : resourcesDates.values()) {
            dates.addAll(resourceDates);
        }

        List<Daily_Assignment__c> records = new List<Daily_Assignment__c>();
        for(Daily_Assignment__c record : [select Contact__c, Daily_Date__c from Daily_Assignment__c where Contact__c in :resourcesDates.keySet() and Daily_Date__c in :dates and Assignment__r.Inactive__c != true and Assignment__r.Projects__r.Name not in :RPRFResourceService.DayOffProjects]) {
            if(resourcesDates.get(record.Contact__c)?.contains(record.Daily_Date__c) == true) {
                records.add(record);
            }
        }

        delete records;
    }

    public void processApprovedTimesheets(List<Timesheet__c> records) {
        List<SFDC_Timecard__c> timecards = [select Date__c, Hours__c, Assignment__c, Assignment__r.Resource__c, Timesheet__c, Timesheet__r.Start_Date__c, Timesheet__r.End_Date__c from SFDC_Timecard__c where Timesheet__c in :records and Date__c != null and Assignment__c != null and Hours__c != null and Type__c = 'Billable'];
        if (timecards.isEmpty()) return;

        Set<String> usedTimesheets = new Set<String>();
        Map<ID, List<Map<String, Date>>> assignments = new Map<ID, List<Map<String, Date>>>();
        for (SFDC_Timecard__c timecard : timecards) {
            if(!assignments.containsKey(timecard.Assignment__c)) assignments.put(timecard.Assignment__c, new List<Map<String, Date>>());
            
            String key = (String)timecard.Assignment__c + timecard.Timesheet__c;
            if(!usedTimesheets.contains(key)) {
                usedTimesheets.add(key);
                assignments.get(timecard.Assignment__c).add(new Map<String, Date>{
                    'from' => timecard.Timesheet__r.Start_Date__c, 
                    'to' => timecard.Timesheet__r.End_Date__c
                });
            }
        }

        recalculateActualHours(assignments, true);
        recalculateProjectedHours(new List<ID>(assignments.keySet()));
    }

    public void recalculateActualHours(ID assignmentId) {
        recalculateActualHours(new List<ID>{assignmentId});
    }

    public void recalculateActualHours(List<ID> assignmentsIds) {
        Map<ID, List<Map<String, Date>>> assignments = new Map<ID, List<Map<String, Date>>>();
        for(ID assignmentId : assignmentsIds) {
            assignments.put(assignmentId, null);
        }

        recalculateActualHours(assignments, false);
    }

    public void recalculateActualHours(Map<ID, List<Map<String, Date>>> assignments, Boolean updateAllActuals) {
        Date fromDate, toDate;
        List<ID> assignmentsIds = new List<ID>();
        for (ID assignmentId : assignments.keySet()) {
            assignmentsIds.add(assignmentId);

            if(assignments.get(assignmentId) != null) {
                for(Map<String, Date> item : assignments.get(assignmentId)) {
                    if(fromDate == null || fromDate > item.get('from')) fromDate = item.get('from');
                    if(toDate == null || toDate < item.get('to')) toDate = item.get('to');   
                }
            }
        }

        Map<ID, SFDC_Assignment__c> assignmentsMap = new Map<ID, SFDC_Assignment__c>([select Resource__c from SFDC_Assignment__c where Id in :assignmentsIds]);
        Map<ID, Map<Date, Decimal>> assignmentsActualDates = getAssignmentsActualDates(assignmentsIds, fromDate, toDate);
        List<Daily_Assignment__c> dailyAssignmentsForUpdate = new List<Daily_Assignment__c>();

        String conditions = 'Assignment__c in :param1 ';
        if(fromDate != null) conditions += ' and Daily_Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd');
        if(toDate != null) conditions += ' and Daily_Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd');

        String query = 'select Assignment__c, Daily_Date__c, Actual_Hours__c, Locked__c from Daily_Assignment__c where ' + conditions;
        List<Daily_Assignment__c> dailyAssignments = (List<Daily_Assignment__c>)SObjectService.getInstance().loadSObjects(query, new List<Object> {assignmentsIds});
        for(Daily_Assignment__c dailyAssignment : dailyAssignments) {
            List<Map<String, Date>> dates = assignments.get(dailyAssignment.Assignment__c);
            if(dates != null) {
                Boolean inRange = false;
                for(Map<String, Date> item : dates) {
                    if(dailyAssignment.Daily_Date__c >= item.get('from') && dailyAssignment.Daily_Date__c <= item.get('to')){
                        inRange = true;
                    } 
                }

                if(!inRange) continue;
            }

            Map<Date, Decimal> actualDates = assignmentsActualDates.get(dailyAssignment.Assignment__c);
            if (dailyAssignment.Actual_Hours__c != actualDates?.get(dailyAssignment.Daily_Date__c)) {
                dailyAssignment.Actual_Hours__c = actualDates?.get(dailyAssignment.Daily_Date__c);
                if(dailyAssignment.Actual_Hours__c == null) dailyAssignment.Actual_Hours__c = 0;
                dailyAssignmentsForUpdate.add(dailyAssignment);
            }else if(updateAllActuals == true && dailyAssignment.Actual_Hours__c == null) {
                dailyAssignment.Actual_Hours__c = 0;
                dailyAssignmentsForUpdate.add(dailyAssignment);
            }

            actualDates?.remove(dailyAssignment.Daily_Date__c);
        }

        for(ID assignmentId : assignmentsActualDates.keySet()) {
            SFDC_Assignment__c assignment = assignmentsMap.get(assignmentId);
            Map<Date, Decimal> actualDates = assignmentsActualDates.get(assignmentId);
            for(Date day : actualDates.keySet()) {
                dailyAssignmentsForUpdate.add(new Daily_Assignment__c( 
                    Name = 'Assignment for ' + RPRFUtilities.formatDate(day, 'yyyy-MM-dd'),
                    Assignment__c = assignmentId,
                    Contact__c = assignment.Resource__c,
                    Daily_Date__c = day,
                    Actual_Hours__c = actualDates.get(day)
                ));
            }
        }

        try {
            isDailyAssignmentAutomationRan = true;
            upsert dailyAssignmentsForUpdate;
        } finally {
            isDailyAssignmentAutomationRan = false;
        }
    }

    public void recalculateProjectedHours(ID assignmentId) {
        recalculateProjectedHours(new List<ID>{assignmentId});
    }

    public void recalculateProjectedHours(List<ID> assignmentsIds) {
        Map<ID, Date> assignmentsMaxDates = new Map<ID, Date>();
        for(SObject record : [select Assignment__c, MAX(Date__c) dt from SFDC_Timecard__c where Timesheet_Status__c = 'Approved' and Type__c = 'Billable' and Assignment__c in :assignmentsIds and Assignment__r.Projects__r.Unforcasted_Project__c = false and Assignment__r.Inactive__c = false group by Assignment__c]) {
            assignmentsMaxDates.put((ID)record.get('Assignment__c'), (Date)record.get('dt'));
        }
        system.debug('assignments with timecards:' + assignmentsMaxDates.size());
        
        Map<ID, Date> assignmentsTimesheetEndDates = new Map<ID, Date>();
        for (SFDC_Timecard__c record : [select Assignment__c, Date__c, Timesheet__r.End_Date__c from SFDC_Timecard__c where Timesheet_Status__c = 'Approved' and Assignment__c in :assignmentsMaxDates.keySet() and Type__c = 'Billable' and Date__c in :assignmentsMaxDates.values()]) {
            if (assignmentsMaxDates.get(record.Assignment__c) == record.Date__c) {
                assignmentsTimesheetEndDates.put(record.Assignment__c, record.Timesheet__r.End_Date__c.addDays(1));
            }            
        }
        system.debug('assignment timesheet end dates 1:' + assignmentsTimesheetEndDates);
        
        for(ID assignmentId : assignmentsIds) {
            if(!assignmentsTimesheetEndDates.containsKey(assignmentId)){
                assignmentsTimesheetEndDates.put(assignmentId, null);
            }
        }
        system.debug('assignment timesheet end dates 2:' + assignmentsTimesheetEndDates);
        

        recalculateProjectedHours(assignmentsTimesheetEndDates);
    }

    public void recalculateProjectedHours(Map<ID, Date> assignmentsDates) {
        Map<ID, SFDC_Assignment__c> assignmentsMap = new Map<ID, SFDC_Assignment__c>([select Number_Of_Hours__c, Daily_Max__c, Resource__c, Start_Date__c, End_Date__c from SFDC_Assignment__c where Projects__r.Unforcasted_Project__c = false and Id in :assignmentsDates.keySet()]);
        Map<ID, Decimal> assignmentsActuals = new Map<ID, Decimal>();
        for(SObject record : [select Assignment__c, SUM(Actual_Hours__c) total from Daily_Assignment__c where Assignment__c in :assignmentsDates.keySet() group by Assignment__c]) {
            assignmentsActuals.put((ID)record.get('Assignment__c'), (Decimal)record.get('total'));
        }

        List<ID> assignmentsIds = new List<ID>(assignmentsMap.keySet());
        List<Daily_Assignment__c> dailyAssignmentsForUpsert = new List<Daily_Assignment__c>();
        List<Daily_Assignment__c> dailyAssignmentsForDelete = new List<Daily_Assignment__c>();
        while(!assignmentsIds.isEmpty()) {
            ID assignmentId = assignmentsIds[0];
            recalculateProjectedHours(assignmentsMap.get(assignmentId), assignmentsActuals.get(assignmentId), assignmentsDates.get(assignmentId), dailyAssignmentsForUpsert, dailyAssignmentsForDelete);
            assignmentsIds.remove(0);

            if(Limits.getQueries() + 20 >= Limits.getLimitQueries() || Limits.getCpuTime() + 2000 >= Limits.getLimitCpuTime()) break;
        }

        try {
            isDailyAssignmentAutomationRan = true;
            upsert dailyAssignmentsForUpsert;
            delete dailyAssignmentsForDelete;
        } finally {
            isDailyAssignmentAutomationRan = false;
        }

        if(!assignmentsIds.isEmpty()) {
            QueueService.start('recalculateProjectedHours', assignmentsIds, 'RPRFAssignmentService');
        }
    }

    private void recalculateProjectedHours(SFDC_Assignment__c assignment, Decimal actualsTotal, Date timesheetEndDate, List<Daily_Assignment__c> dailyAssignmentsForUpsert, List<Daily_Assignment__c> dailyAssignmentsForDelete) {
        if(timesheetEndDate == null) timesheetEndDate = assignment.Start_Date__c.addDays(-1);

        List<Daily_Assignment__c> records = [select Actual_Hours__c, Assignment__c, Projected_Hours__c, Daily_Date__c, Locked__c from Daily_Assignment__c where Assignment__c = :assignment.Id and Daily_Date__c > :timesheetEndDate order by Daily_Date__c asc];
        Set<Date> unavailabeDates = getUnavailabeDatesByResource(assignment.Resource__c, timesheetEndDate, assignment.End_Date__c);
        
        Set<Date> usedDates = new Set<Date>();
        for(Daily_Assignment__c record : records) {
            usedDates.add(record.Daily_Date__c);
        }
        
        for(Date day = timesheetEndDate; day <= assignment.End_Date__c; day = day.addDays(1)) {
            if(unavailabeDates.contains(day) || usedDates.contains(day)) continue;

            records.add(new Daily_Assignment__c(
                Name = 'Assignment for ' + RPRFUtilities.formatDate(day, 'yyyy-MM-dd'),
                Assignment__c = assignment.Id,
                Contact__c = assignment.Resource__c,
                Daily_Date__c = day,
                Projected_Hours__c = 0
            ));
        }
        
        Integer numberOfFutureAvailableDays = records.size();
        Decimal lockedProjectedHours = 0;
        for(Daily_Assignment__c record : records) {
            if(record.Locked__c == true) {
                lockedProjectedHours = lockedProjectedHours + (record.Projected_Hours__c == null ? 0 : record.Projected_Hours__c);
                numberOfFutureAvailableDays--;
            }
        }

        if(numberOfFutureAvailableDays == 0) return;

        Decimal overloadHours = 0;
        if (actualsTotal == null) actualsTotal = 0;

        Decimal numberOfHours = assignment.Number_Of_Hours__c;
        if(numberOfHours == null) numberOfHours = 0;
        numberOfHours = numberOfHours - actualsTotal - lockedProjectedHours;
        if(numberOfHours < 0) numberOfHours = 0;

        if(assignment.Daily_Max__c > 0) {
            for(Daily_Assignment__c dailyAssignment : records) {
                if(dailyAssignment.Locked__c == true) continue;

                Decimal projectedHours = (unavailabeDates.contains(dailyAssignment.Daily_Date__c) ? 0.0 : assignment.Daily_Max__c);
                if(numberOfHours < projectedHours) projectedHours = numberOfHours;
                numberOfHours -= projectedHours;

                dailyAssignment.Projected_Hours__c = projectedHours;
            }
        }else {
            for(Daily_Assignment__c dailyAssignment : records) {
                if(dailyAssignment.Locked__c == true) continue;
                dailyAssignment.Projected_Hours__c = 0.0;
            }
            /*
            Decimal projectedHoursPerDay = (numberOfHours / numberOfFutureAvailableDays).round(System.RoundingMode.CEILING);
            //if(assignment.Daily_Max__c > 0 && projectedHoursPerDay > assignment.Daily_Max__c) projectedHoursPerDay = assignment.Daily_Max__c;
            if(projectedHoursPerDay * numberOfFutureAvailableDays > numberOfHours) overloadHours = projectedHoursPerDay * numberOfFutureAvailableDays - numberOfHours;
            
            for(Daily_Assignment__c dailyAssignment : records) {
                if(dailyAssignment.Locked__c == true) continue;
                dailyAssignment.Projected_Hours__c = projectedHoursPerDay;
            }
    
            Decimal prvOverloadHours;
            while (overloadHours > 0 && overloadHours != prvOverloadHours) {
                prvOverloadHours = overloadHours;
                for(Integer i = records.size() - 1; i >= 0; i--) {
                    if(records[i].Locked__c == true) continue;
                    if(records[i].Projected_Hours__c > 0) {
                        Decimal step = (overloadHours < 1 ? overloadHours : 1);
                        records[i].Projected_Hours__c -= step;
                        overloadHours -= step;   
                    } else {
                        overloadHours = 0;
                    }
                    if(overloadHours <= 0) break;
                }
            }*/
        }
        
        for(Daily_Assignment__c record : records) {
            if(record.Locked__c == true) continue;

            if(unavailabeDates.contains(record.Daily_Date__c)) {
                dailyAssignmentsForDelete.add(record);
            }else {
                dailyAssignmentsForUpsert.add(record);
            }
        }
    }

    private List<Daily_Assignment__c> buildDailyAssignmentsByDailyMax(SFDC_Assignment__c assignment, Integer numberOfAvailableDays, Set<Date> unavailabeDates) {
        Decimal numberOfHours = assignment.Number_Of_Hours__c;
        if(numberOfHours == null) numberOfHours = 0;

        Decimal projectedHoursPerDay = assignment.Daily_Max__c;
        Date fromDate = assignment.Start_Date__c;
        Date toDate = assignment.End_Date__c;
        List<Daily_Assignment__c> dailyAssignments = new List<Daily_Assignment__c>();
        for(Date day = fromDate; day <= toDate; day = day.addDays(1)) {
            if(unavailabeDates.contains(day)) continue;

            Decimal projectedHours = assignment.Daily_Max__c;
            if(numberOfHours < projectedHours) projectedHours = numberOfHours;
            numberOfHours -= projectedHours;

            dailyAssignments.add(new Daily_Assignment__c(
                Name = 'Assignment for ' + RPRFUtilities.formatDate(day, 'yyyy-MM-dd'),
                Assignment__c = assignment.Id,
                Contact__c = assignment.Resource__c,
                Daily_Date__c = day,
                Projected_Hours__c = projectedHours
            ));
        }

        return dailyAssignments;
    }

    private List<Daily_Assignment__c> buildDailyAssignmentsByDefault(SFDC_Assignment__c assignment, Integer numberOfAvailableDays, Set<Date> unavailabeDates) {
        Decimal numberOfHours = assignment.Number_Of_Hours__c;
        if(numberOfHours == null) numberOfHours = 0;

        Decimal averageProjectedHoursPerDay = (numberOfHours / numberOfAvailableDays).round(System.RoundingMode.CEILING), overloadHours = 0;
        if(averageProjectedHoursPerDay * numberOfAvailableDays > numberOfHours) overloadHours = averageProjectedHoursPerDay * numberOfAvailableDays - numberOfHours;

        Date fromDate = assignment.Start_Date__c;
        Date toDate = assignment.End_Date__c;
        List<Daily_Assignment__c> dailyAssignments = new List<Daily_Assignment__c>();
        for(Date day = fromDate; day <= toDate; day = day.addDays(1)) {
            if(unavailabeDates.contains(day)) continue;

            dailyAssignments.add(new Daily_Assignment__c(
                Name = 'Assignment for ' + RPRFUtilities.formatDate(day, 'yyyy-MM-dd'),
                Assignment__c = assignment.Id,
                Contact__c = assignment.Resource__c,
                Daily_Date__c = day,
                Projected_Hours__c = 0
                //Projected_Hours__c = averageProjectedHoursPerDay
            ));
        }

        /*
        Decimal prvOverloadHours;
        while (overloadHours > 0 && overloadHours != prvOverloadHours) {
            prvOverloadHours = overloadHours;
            for(Integer i = dailyAssignments.size() - 1; i >= 0; i--) {                
                if(dailyAssignments[i].Projected_Hours__c > 0) {
                    Decimal step = (overloadHours < 1 ? overloadHours : 1);
                    dailyAssignments[i].Projected_Hours__c -= step;
                    overloadHours -= step;     
                } else {
                    overloadHours = 0;
                }

                if(overloadHours <= 0) break;
            }
        }
        */

        return dailyAssignments;
    }

    /********************* QUEUEABLE SECTION **************************/

    public Object call(String action, Map<String, Object> args) {
		try{
            if(action == 'recalculateDailyAssignments') {
                List<ID> assignmentsIds = (List<ID>)args.get('data');
                recalculateDailyAssignments(assignmentsIds[0], false, false);
                if(!assignmentsIds.isEmpty()) assignmentsIds.remove(0);
                if(!assignmentsIds.isEmpty()) QueueService.start('recalculateDailyAssignments', assignmentsIds, 'RPRFAssignmentService');
            }else if(action == 'createResourceDailyAssignments') {
                createResourceDailyAssignments((Map<ID, Set<Date>>)args.get('data'));
            }else if(action == 'recalculateProjectedHours') {
                recalculateProjectedHours((List<ID>)args.get('data'));
            }
        }catch(Exception ex){
            EmailService.getInstance().handleErrors(new List<String>{RPRFUtilities.getExceptionMessage(ex, true)}, 'RPRFAssignmentService(' + action + ')', null, true);
        }

		return null;
	}
}