/******************************************************************************
// Project:         Resource Planning and Revenue Forecasting
// Summary:         Service class that implements business logic and methods for working with Project Resources
// Test Class:      RPRFResourceServiceTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 04/29/2024 - created
*******************************************************************************/

public with sharing class RPRFResourceService 
{
    private static RPRFResourceService instance;

    public static String HOLIDAYS_PROJECT_NAME = 'Company Internal - Company Holiday';
    public static String PTO_PROJECT_NAME = 'Company Internal - FTO';
    public static List<String> DayOffProjects = new List<String> {'Company Internal'};
    public static List<String> DayOffProjectsLines = new List<String> {HOLIDAYS_PROJECT_NAME, PTO_PROJECT_NAME};

    private static Set<String> TIMECARD_FIELDS = new Set<String> {
        'Assignment__c', 'Assignment__r.Resource__c', 'Assignment__r.Resource__r.Name', 'Date__c', 
        'Description_of_Work__c', 'Hours__c'
    };

	/*********************** STATIC SECTION ***********************/

	public static RPRFResourceService getInstance() {
		if(instance == null) instance = new RPRFResourceService();
		return instance;
	}

	/*********************** PUBLIC SECTION ***********************/

    public List<Project_Line_Item__c> getHolidaysProjectLines() {
        if(!RPRFUtilities.containsInCache('HolidaysProjectLines')) {
            List<Project_Line_Item__c> records = [select Name, Project__c, Project__r.Name from Project_Line_Item__c where Name in :DayOffProjectsLines and Project__r.Name in :DayOffProjects];
            RPRFUtilities.addToCache('HolidaysProjectLines', records);
        }

        return (List<Project_Line_Item__c>)RPRFUtilities.extractFromCache('HolidaysProjectLines');
    }
    
    public Set<Date> getUnavailabeDates(ID resourceId, Date fromDate, Date toDate) {
        Map<ID, Set<Date>> unavailabeDates = getUnavailabeDates(new Set<ID>{resourceId}, fromDate, toDate);
        return unavailabeDates.containsKey(resourceId) ? unavailabeDates.get(resourceId) : new Set<Date>();
    }

    public Map<ID, Set<Date>> getUnavailabeDates(Set<ID> resourcesIds, Date fromDate, Date toDate) {
        Map<ID, Set<Date>> result = new Map<ID, Set<Date>>();
        if(fromDate == null || toDate == null) return result;

        for(SFDC_Timecard__c record : [select Project_Line_Item__r.Name, Assignment__r.Resource__c, Date__c from SFDC_Timecard__c 
                                        where Project_Line_Item__r.Project__r.unforcasted_project__c=false
                                            and ((Project_Line_Item__r.Name = :PTO_PROJECT_NAME and Assignment__r.Resource__c in :resourcesIds) or Project_Line_Item__r.Name = :HOLIDAYS_PROJECT_NAME) 
                                            and Date__c >= :fromDate 
                                            and Date__c <= :toDate]) {
            if(record.Project_Line_Item__r.Name == HOLIDAYS_PROJECT_NAME) {
                for(ID resourceId : resourcesIds) {
                    if(!result.containsKey(resourceId)) result.put(resourceId, new Set<Date>());
                    result.get(resourceId).add(record.Date__c);
                }
            }else {
                if(!result.containsKey(record.Assignment__r.Resource__c)) result.put(record.Assignment__r.Resource__c, new Set<Date>());
                result.get(record.Assignment__r.Resource__c).add(record.Date__c);
            }
        }

        return result;
    }

    public List<SFDC_Timecard__c> getHolidays(Set<ID> resourcesIds, Date fromDate, Date toDate) {
        if(fromDate == null || toDate == null) return new List<SFDC_Timecard__c>();

        String conditions = 'Project_Line_Item__r.Project__r.Name in :param1 and Project_Line_Item__r.Name = :param2'; 
        if(resourcesIds != null && !resourcesIds.isEmpty()) conditions += ' and Assignment__r.Resource__c in :param3';
        conditions = '(' + conditions + ') and Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd') + ' and Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd');

        return (List<SFDC_Timecard__c>)SObjectService.getInstance().loadSObjects('SFDC_Timecard__c', TIMECARD_FIELDS, conditions, null, null, null, new List<Object>{DayOffProjects, HOLIDAYS_PROJECT_NAME, resourcesIds});
    }

    public List<SFDC_Timecard__c> getPTOs(Set<ID> resourcesIds, Date fromDate, Date toDate) {
        if(fromDate == null || toDate == null) return new List<SFDC_Timecard__c>();

        String conditions = 'Project_Line_Item__r.Project__r.Name in :param1 and Project_Line_Item__r.Name = :param2'; 
        if(resourcesIds != null && !resourcesIds.isEmpty()) conditions += ' and Assignment__r.Resource__c in :param3';
        conditions = '(' + conditions + ') and Date__c >= ' + RPRFUtilities.formatDate(fromDate, 'yyyy-MM-dd') + ' and Date__c <= ' + RPRFUtilities.formatDate(toDate, 'yyyy-MM-dd');

        return (List<SFDC_Timecard__c>)SObjectService.getInstance().loadSObjects('SFDC_Timecard__c', TIMECARD_FIELDS, conditions, null, null, null, new List<Object>{DayOffProjects, PTO_PROJECT_NAME, resourcesIds});
    }
}