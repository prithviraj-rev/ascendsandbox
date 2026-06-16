public class AccountHandler {
    Public Static List<AccountTeamMember> ATMs;
    
    Public Static void getAccountTeam (List<Account> newTrigger, Map<Id,Account> oldMapTrigger){
        Set<Id> aIds = new Set<Id>(new Map<Id, Account>(newTrigger).keySet()); 
        ATMs = ([Select TeamMemberRole, UserId, AccountId FROM AccountTeamMember WHERE AccountId in : aIds]);
    }
    
    Public Static void insertAccountTeam(List<Account> newTrigger, Map<Id,Account> oldMapTrigger){
        List<AccountTeamMember> newATMs = new List<AccountTeamMember>();
        for(Account a : newTrigger){
            AccountTeamMember atm = new AccountTeamMember(AccountId = a.Id, TeamMemberRole = 'Opportunity Owner', UserId = a.OwnerId);
            newATMs.add(atm);
        }
        if(newATMs != NULL && !newATMs.IsEmpty()){
            insert newATMs;
        }
    }
    
    Public Static void updateAccountTeam(Map<Id,Account> newMapTrigger, Map<Id,Account> oldMapTrigger){
        List<AccountTeamMember> newATMs = new List<AccountTeamMember>();
        if(ATMs != NULL && !ATMs.IsEmpty()){
            for(AccountTeamMember atm : ATMs){
                if(newMapTrigger.get(atm.AccountId).OwnerId == oldMapTrigger.get(atm.AccountId).OwnerId){
                    continue; 
                }
                else if(atm.TeamMemberRole != 'Opportunity Owner' && atm.TeamMemberRole != 'Account Owner'){
                    AccountTeamMember at1 = new AccountTeamMember(AccountId = atm.AccountId, TeamMemberRole = atm.TeamMemberRole, UserId = atm.UserId);
                    newATMs.add(at1);
                }
                else{
                    AccountTeamMember at2 = new AccountTeamMember(AccountId = atm.AccountId, TeamMemberRole = atm.TeamMemberRole, UserId = newMapTrigger.get(atm.accountId).OwnerId);
                    newATMs.add(at2);
                }
                
            }
        }
        if(newATMs != NULL && !newATMs.IsEmpty()){
            insert newATMs;
        }
    }

    //build collection of changed CSMs with Sets of AccountIDs indexed by user.
    public static void updateCSM(List<Account> newTrigger, Map<Id,Account> oldMapTrigger){
        map<id, set<Id>> CSMAccountsByUserId = new map<Id, set<Id>>();
        for (account a: newTrigger){
            account oldAcct = (oldMapTrigger!=null && oldMapTrigger.containsKey(a.Id))?oldMapTrigger.get(a.Id):null;
            if (a.ClientSuccessManager__c !=null && (oldAcct==null || a.ClientSuccessManager__c!=oldAcct.ClientSuccessManager__c)){
                set<Id> CSMAccounts;
                if (!CSMAccountsByUserId.containsKey(a.ClientSuccessManager__c)){
                    CSMAccounts = new set<Id>();
                    CSMAccountsByUserId.put(a.ClientSuccessManager__c, CSMAccounts);
                } else {
                    CSMAccounts = CSMAccountsByUserId.get(a.ClientSuccessManager__c);
                }
                CSMAccounts.add(a.Id);
            }
        }
        ClientSuccessHelper.ProcessCSMChanges(CSMAccountsByUserId);
    }
}