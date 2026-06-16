public with sharing class ClientSuccessHelper {
    public static void ProcessCSMChanges(map<Id, set<Id>> accountIdsByUser){
        map<Id, Contact> resourceByUserId = new map<Id,Contact>();
        map<id, SFDC_Projects__c> projectsForAccounts = new map<Id,SFDC_Projects__c>();
        Id clientServiceProjectRT = SObjectType.SFDC_Projects__c.getRecordTypeInfosByDeveloperName().get('Client_Success').getRecordTypeId();
        list<account>AscendSetup = [select id, name from account where name='Ascend Technologies'];
        Account AscendAccount = (!AscendSetup.isEmpty())?AscendSetup[0]:null;
        map<Id, set<Id>> accountIdsByUserAssignmentsToCreate = new map<Id, set<Id>>();
        //collected list of accounts
        set<Id> collectAccounts = new set<Id>();
        for (set<Id> accIds:accountIdsByUser.values()){
            //stuff account sets with Ascend account;
            if (AscendAccount!=null){
                accIds.add(AscendAccount.Id);
            }
            collectAccounts.addAll(accIds);
        }

        map<Id, Account> accountData = new map<Id, Account>([select id, name from account where id in:collectAccounts]);
        system.debug('Accounts for CSM ' + JSON.serialize(accountData));

        //Resources for identified users
        list<Contact> ResourceList = [select id, name, Resource_User_Record__c from contact where recordtype.name='resource' and Resource_User_Record__c in:accountIdsByUser.keyset()];
        for (Contact c:ResourceList){
            ResourceByUserId.put(c.Resource_User_Record__c, c);
            accountIdsByUserAssignmentsToCreate.put(c.Resource_User_Record__c, new set<Id>());
            
        }
        system.debug('Resource collections');
        system.debug(ResourceByUserId);
        system.debug(accountIdsByUserAssignmentsToCreate);

        //Existing Projects for identified clients
        set<Id>collectProjectIds = new set<id>();
        list<SFDC_Projects__c> existingProjects = [select id, name, Account__c from SFDC_Projects__c where recordtype.developername='Client_Success' and account__c in :collectAccounts order by createddate desc];
        for (SFDC_Projects__c p:existingProjects){
            if (!projectsForAccounts.containsKey(p.Account__c)){
                projectsForAccounts.put(p.Account__c, p);
                collectProjectIds.add(p.Id);

            }
        }
        system.debug('Existing projects ');
        system.debug(projectsForAccounts);

        list<SFDC_Projects__c> newProjects = new list<SFDC_Projects__c>();
        for (Id userId:accountIdsByUser.keyset()){

            for (Id accId:accountIdsByUser.get(userId)){
                if (accountIdsByUserAssignmentsToCreate.containsKey(userId)){
                    if (!projectsForAccounts.containskey(accID)){
                        //generate missing project
                        system.debug('Adding new project ' + accountData.get(accId).Name);
                        SFDC_Projects__c p = new SFDC_Projects__c(recordTypeId=clientServiceProjectRT);
                        p.Name = string.format('{0} - Client Success', new list<String>{accountData.get(accId).Name});
                        p.Account__c = accId;
                        p.Project_Stage__c = 'Active';
                        p.Service__c = 'Client Success';
                        p.Project_Type__c = null;
                        p.ProjectService__c = null;
                        p.Default_Case_Owner__c = 'No Auto Assign';
                        p.Start_Date__c = Date.newInstance(Date.today().year(),1,1);
                        p.End_Date__c = Date.newInstance(2099,12,31);//Date.newInstance(Date.today().year()+10,12,31);
                        p.Project_Status__c = 'Green';
                        p.Project_Lead__c = ResourceByUserId.get(userId).Id;
                        p.Payment_terms__c = 'Net 30';
                        p.Billing__c = 'Fixed';
                        p.Unforcasted_Project__c = true;
                        newProjects.add(p);
                        projectsForAccounts.put(accId, p);
                    }

                    accountIdsByUserAssignmentsToCreate.get(userId).add(accId);
                } else {
                    system.debug('User has no resource: ' + userId);
                }
            }
        }
        //insert new projects
        if (!newProjects.isEmpty()){
            insert newProjects;
            for (SFDC_Projects__c p:newProjects){
                collectProjectIds.add(p.Id);
            }
            system.debug('Insert new projects');
            system.debug(newProjects);
        }


        //Ensure user has an assignment
        list<sfdc_assignment__c> assignmentList = [select id, name, projects__c, Projects__r.Account__c, resource__r.resource_user_record__c, resource__r.name from  sfdc_assignment__c where projects__c in:collectProjectIds and inactive__c=false];
        for (sfdc_assignment__c a: assignmentList){
            system.debug(string.format('Existing assignment check, {0}', new list<object>{a.name}));
            if (accountIdsByUserAssignmentsToCreate.containskey(a.resource__r.resource_user_record__c)){
                system.debug('Remove assignment, already exists');
                set<Id> accountsForUser = accountIdsByUserAssignmentsToCreate.get(a.resource__r.resource_user_record__c);
                accountsForUser.remove(a.Projects__r.account__c);
            }
        }
        system.debug('Existing assignments for user');
        system.debug(accountIdsByUserAssignmentsToCreate);

        //accountIdsByUserAssignmentsToCreate remains assignmets to create
        list<sfdc_assignment__c> newAssignments = new list<sfdc_assignment__c>();
        for (Id userId:accountIdsByUserAssignmentsToCreate.keyset()){
            for (Id accId:accountIdsByUserAssignmentsToCreate.get(userId)){
                SFDC_Projects__c p = projectsForAccounts.get(accId);
                if (ResourceByUserId.containsKey(userId)){
                    contact c = ResourceByUserId.get(userId);
                    sfdc_assignment__c a = new sfdc_assignment__c();
                    system.debug(string.format('Adding assignment {0} - {1}', new list<string>{c.name,p.name}));
                    
                    a.name = string.format('{0} - {1}', new list<string>{c.name,p.name}).left(80);
                    a.resource__c = c.Id;
                    a.Projects__c = p.Id;
                    a.Role__c = 'Client Success';
                    a.Start_Date__c = Date.newInstance(Date.today().year(),1,1);
                    a.End_Date__c = Date.newInstance(2099,12,31);//Date.newInstance(Date.today().year()+10,12,31);
                    a.Number_Of_Hours__c = 1000;
                    a.Daily_Max__c = 1;
                    newAssignments.add(a);
                }
            }
        }
        if (!newAssignments.isEmpty()){
            insert newAssignments;

            system.debug('insert new assignmetns');
        }

        //Ensure all projects have the current Line Item template
        list<ProjectLineItemTemplate__mdt> LineTemplate = [select Label, EstHours__c, Ascend_Only__c from ProjectLineItemTemplate__mdt where TemplateType__c='Client Success' and Active__c=true];

        list<project_line_item__c> existingProjectLines = [select id, name,  Project__c from project_line_item__c where project__c in:collectProjectIds];
        map<id, map<string,project_line_item__c>> LinesByProjectAndName = new map<id, map<string,project_line_item__c>>();

        for (project_line_item__c pli: existingProjectLines){
            map<string, project_line_item__c> linesByName;
            if (!linesByProjectAndName.containskey(pli.project__c)){
                linesByName = new map<string, project_line_item__c>();
                linesByProjectAndName.put(pli.project__c, linesByName);
            } else {
                linesByName = linesByProjectAndName.get(pli.project__c);
            }
            linesByName.put(pli.name, pli);
        }

        list<project_Line_Item__c> newProjectLines = new list<project_Line_Item__c>();
        for (SFDC_Projects__c p: projectsForAccounts.values()){
            account a = accountData.get(p.Account__c);
            map<string, project_line_item__c> linesByName = linesByProjectAndName.containskey(p.Id)?linesByProjectAndName.get(p.Id):new map<string, project_line_item__c>();
            for (ProjectLineItemTemplate__mdt tmp: LineTemplate){
                string expName = expectedName(a.Name, tmp.Label);
                if (!linesByName.containsKey(expName)){
                    if ((tmp.Ascend_Only__c==true && AscendAccount!=null && a.Id==AscendAccount.Id)||tmp.Ascend_Only__c==false){
                        project_line_item__c pli = new project_line_item__c(project__c=p.Id, name=expName, est_hours__c=tmp.EstHours__c);
                        newProjectLines.add(pli);
                    }
                }
            }
        }
        if (!newProjectLines.IsEmpty()){
            insert newProjectLines;
            system.debug('Adding line items');
            system.debug(newProjectLines);
        }

    }

    @testvisible
    private static string expectedName (string AccountName, string ItemName){
        string ending = string.format(' - {0}', new list<string>{ItemName});
        integer charsForAcct = 80-ending.length();
        return string.format('{0}{1}', new list<string>{AccountName.left(charsForAcct),ending});
    }

    //generate collection for entire CS team
    public static void ensureProjects(){
        list<account>AscendSetup = [select id, name from account where name='Ascend Technologies'];
        Account AscendAccount = (!AscendSetup.isEmpty())?AscendSetup[0]:null;
        
        map<Id, set<Id>> AccountIdsByUserId = new map<Id,Set<Id>>();
        List<User> CSUsers = [SELECT Id, Name, Email FROM User WHERE UserRole.name = 'Ascend CSM Team' AND IsActive = true];
        for(user u:CSUsers){
            set<Id> init = new set<Id>();
            if (AscendAccount!=null){
                init.add(AscendAccount.Id);
            }
            AccountIdsByUserId.put(u.Id, init);
        }
        list<Account> CSMAccounts = [select id, name, ClientSuccessManager__c, ClientSuccessManager__r.name from account where ClientSuccessManager__c!=null];
        for (Account a: CSMAccounts){
            set<Id> accIds;
            if (AccountIdsByUserId.containsKey(a.ClientSuccessManager__c)){
                accIds = AccountIdsByUserId.get(a.ClientSuccessManager__c);
            } else {
                accIds = new set<Id>{AscendAccount.Id};
                AccountIdsByUserId.put(a.ClientSuccessManager__c, accIds);
            }
            accIds.add(a.Id);
        }
        system.debug(json.serializepretty(AccountIdsByUserId));
        ProcessCSMChanges(AccountIdsByUserId);
    }
}