trigger timecard_project_stage_check on SFDC_Timecard__c (before insert, before update) {
    map<Id, string> projectStatus = new map<Id, string>();
    set<string> ineligibleStages = new set<string>{'Implemented', 'On Hold', 'Closed'};
    try{
        PermissionSetAssignment psa = [select Id from PermissionSetAssignment 
                                       where PermissionSet.Name = 'Edit_Timecard_Once_Billing_Starts' 
                                       and AssigneeId =: UserInfo.getUserId()];
        system.debug('Trigger: timecard_project_stage_check has been bypassed by a user with the PermissionSet: Edit_Timecard_Once_Billing_Starts');
    }catch(exception e){
        system.debug('Trigger: timecard_project_stage_check has been executed');
        for (SFDC_timecard__c tc:trigger.new){
            projectStatus.put(tc.Project_Line_Item__c, null);
        }
        
        for (Project_Line_Item__c pli:[select id, Project__r.Project_Stage__c from Project_Line_Item__c where id in:projectStatus.keyset()]){
            projectStatus.put(pli.Id, pli.Project__r.Project_Stage__c);
        }
        
        for (SFDC_Timecard__c t:trigger.new){
            if (projectStatus.containskey(t.Project_Line_Item__c) && ineligibleStages.contains(projectStatus.get(t.Project_Line_Item__c))){
                t.Project_Line_Item__c.addError('This project is ineligible for timecards ('+projectStatus.get(t.Project_Line_Item__c)+').');
            }
        }
    }
}