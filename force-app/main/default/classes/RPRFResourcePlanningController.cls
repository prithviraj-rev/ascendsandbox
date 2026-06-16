/******************************************************************************
// Summary:         The class controller for rprfResourcePlanning LWC component
// Test Class:      RPRFResourcePlanningControllerTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/04/2024 - created
*******************************************************************************/

public with sharing class RPRFResourcePlanningController implements Callable
{
    private String NOT_ENOUGH_HOURS_MESSAGE = 'There are NOT enough hours to reach the end date. There are {DAYS} days without hours forecasted.';
    private String ESTIMATED_HOURS_EXCEED_MESSAGE = 'Estimated Hours Exceed Available Days in the Assignment. There are {HOURS} extra hours that need to be forecast.';

    private Object getConfiguration(Map<String, Object> params) {
        List<Contact> resources = [select Name, Position__c from Contact where Resource_User_Record__c = :UserInfo.getUserId()];

        Map<String, Object> result = new Map<String, Object>{
            'currentUser' => [select Name, Profile.Name, UserRole.Name from User where Id = :UserInfo.getUserId()],
            'currentResource' => (resources.isEmpty() ? null : resources[0]),
            'canManageResources' => FeatureManagement.checkPermission('Resource_Planning_Manage_All_Resources')
        };

        ID resourceId = (ID)params.get('resourceId');
        if(resourceId != null) {
            resources = (List<Contact>)SObjectService.getInstance().loadSObjects('select Id, Name from Contact where Id = :param1', new List<Object> {resourceId});
            if(!resources.isEmpty()) result.put('resource', resources[0]);
        }

        ID projectId = (ID)params.get('projectId');
        if(projectId != null) {
            List<SFDC_Projects__c> projects = (List<SFDC_Projects__c>)SObjectService.getInstance().loadSObjects('select Id, Name from SFDC_Projects__c where Id = :param1', new List<Object> {projectId});
            if(!projects.isEmpty()) result.put('project', projects[0]);
        }

        return result;
    }

    private Object getWeekConfiguration(Map<String, Object> params) {
        Map<String, Object> result = new Map<String, Object>();
        if(!String.isBlank((String)params.get('resourceId'))) {
            result.put('hasSubmitedForecast', hasSubmitedForecast((ID)params.get('resourceId'), Date.valueOf((String)params.get('date'))));
        }

        return result;

    }

    private Object getAssignments(ID resourceId, ID projectId, Date fromDate, Date toDate) {
        return RPRFAssignmentService.getInstance().getAssignments(resourceId, projectId, fromDate, toDate);
    }

    private Object getDaysOffByResource(ID resourceId, Date fromDate, Date toDate) {
        Set<ID> resourcesIds = new Set<ID>();
        if(resourceId != null) resourcesIds.add(resourceId);

        return new Map<String, Object>{
            'holidays' => RPRFResourceService.getInstance().getHolidays(resourcesIds, fromDate, toDate),
            'pto' => RPRFResourceService.getInstance().getPTOs(resourcesIds, fromDate, toDate)
        };
    }

    private Object getDaysOffByProject(ID projectId, Date fromDate, Date toDate) {
        Set<ID> resourcesIds = new Set<ID>();
        if(projectId != null) {
            for(Contact record : [select Id from Contact where Id in (select Resource__c from SFDC_Assignment__c where Projects__c = :projectId)]) {
                resourcesIds.add(record.Id);
            }
        }

        return new Map<String, Object>{
            'holidays' => RPRFResourceService.getInstance().getHolidays(resourcesIds, fromDate, toDate),
            'pto' => RPRFResourceService.getInstance().getPTOs(resourcesIds, fromDate, toDate)
        };
    }

    private Object saveDailyAssignment(Daily_Assignment__c record) {
        update record;
        return record;
    }

    private Boolean hasSubmitedForecast(ID resourceId, Date day) {
        Date startDate = day.toStartOfWeek();
        Date endDate = startDate.addDays(7);
        return [select count() from Task where WhoId = :resourceId and ActivityDate >= :startDate and ActivityDate < :endDate and Subject like 'Resource Forecast Completed for %'] > 0;
    }

    private Object submitForecast(ID resourceId, String day) {
        Date forDate = Date.valueOf(day);
        Date startDate = forDate.toStartOfWeek();
        Date endDate = startDate.addDays(7);

        if(hasSubmitedForecast(resourceId, forDate)) throw new AuraHelper.AuraException('The forecast was already submitted for this period.'); 

        Contact resource = [select Name from Contact where Id = :resourceId];

        Task record = new Task(
            Subject = 'Resource Forecast Completed for ' + RPRFUtilities.formatDate(startDate, 'MM/dd') + ' to ' + RPRFUtilities.formatDate(endDate, 'MM/dd'),
            ActivityDate = forDate, 
            WhoId = resource.Id,
            Description = resource.Name + ' has marked the resource forecast completed for ' + RPRFUtilities.formatDate(startDate, 'MM/dd') + ' to ' + RPRFUtilities.formatDate(endDate, 'MM/dd'),
            Status = 'Completed',
            Purpose__c = 'Delivery Forecast'
        );

        insert record;

        Map<ID, Date> assignmentsDates = new Map<ID, Date>();
        for(SFDC_Assignment__c assignment : [select Id from SFDC_Assignment__c where Resource__c = :resource.Id and Start_Date__c <= :endDate and End_Date__c > :endDate and Projects__r.Unforcasted_Project__c = false]) {
            assignmentsDates.put(assignment.Id, endDate);
        }
        
        RPRFAssignmentService.getInstance().recalculateProjectedHours(assignmentsDates);
        return record;
    }

    private Object getAssignmentsMessages(List<ID> assignmentsIds) {
        Map<ID, String> result = new Map<ID, String>();
        for(SFDC_Assignment__c record : [select Daily_Max__c, Number_Of_Hours__c, Total_Projected_Hours__c, Hours_Worked_Forecasted__c, Count_of_Daily_Assignments_with_no_hours__c from SFDC_Assignment__c where Id in :assignmentsIds]) {
            String message = null;
            if(record.Number_Of_Hours__c > record.Hours_Worked_Forecasted__c) {
                    message = ESTIMATED_HOURS_EXCEED_MESSAGE.replace('{HOURS}', String.valueOf(record.Number_Of_Hours__c - record.Hours_Worked_Forecasted__c));
            }else if(record.Number_Of_Hours__c <= record.Hours_Worked_Forecasted__c && record.Count_of_Daily_Assignments_with_no_hours__c > 0) {
                message = NOT_ENOUGH_HOURS_MESSAGE.replace('{DAYS}', String.valueOf(record.Count_of_Daily_Assignments_with_no_hours__c));
            }

            result.put(record.Id, message);
        }

        return result;
    }
    
    /*************************** CALLABLE SECTION **********************************/

	public Object call(String actionName, Map<String, Object> params) 
	{
		switch on actionName {
            when 'getConfiguration' {
                return getConfiguration(params);
			}

            when 'getWeekConfiguration' {
                return getWeekConfiguration(params);
			}

            when 'getAssignments' {
                return getAssignments((ID)params.get('resourceId'), (ID)params.get('projectId'), (Date)RPRFUtilities.stringToObject((String)params.get('fromDate'), Schema.DisplayType.Date), (Date)RPRFUtilities.stringToObject((String)params.get('toDate'), Schema.DisplayType.Date));
			}

            when 'getDaysOffByResource' {
                return getDaysOffByResource((ID)params.get('resourceId'), (Date)RPRFUtilities.stringToObject((String)params.get('fromDate'), Schema.DisplayType.Date), (Date)RPRFUtilities.stringToObject((String)params.get('toDate'), Schema.DisplayType.Date));
			}

            when 'getDaysOffByProject' {
                return getDaysOffByProject((ID)params.get('projectId'), (Date)RPRFUtilities.stringToObject((String)params.get('fromDate'), Schema.DisplayType.Date), (Date)RPRFUtilities.stringToObject((String)params.get('toDate'), Schema.DisplayType.Date));
			}

            when 'saveDailyAssignment' {
                return saveDailyAssignment((Daily_Assignment__c)JSON.deserialize(JSON.serialize(params.get('record')), Daily_Assignment__c.class));
			}

            when 'submitForecast' {
                return submitForecast((ID)params.get('resourceId'), (String)params.get('date'));
			}

            when 'getAssignmentsMessages' {
                return getAssignmentsMessages((List<ID>)JSON.deserialize(JSON.serialize(params.get('ids')), List<ID>.class));
			}

		  	when else {
				throw new AuraHelper.AuraException('Invalid action name.');
		  	}
		}
	}
}