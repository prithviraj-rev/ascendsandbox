@isTest
public class AccountTrigger_UT {
    
    @testSetup
    Public Static void setupUsers(){
        List<User> users = new List<User>();
        List<Account> accounts = new List<Account>();
        
        Profile P = [Select Id from Profile limit 1];
        
        User m = new User(firstname = 'Test',
                           lastName = 'Manager',
                           email = 'test.manager@testTTAUT.org',
                           Username = 'test.manager@testTTAUT.org',
                           EmailEncodingKey = 'ISO-8859-1',
                           Alias = 'ttast',
                           TimeZoneSidKey = 'America/Los_Angeles',
                           LocaleSidKey = 'en_US',
                           LanguageLocaleKey = 'en_US',
                           ProfileId = p.Id,
                           IsActive = FALSE);
        Insert m;
        
        User u1 = new User(firstname = 'Test',
                           lastName = 'Test',
                           email = 'test.test@testTTAUT.org',
                           Username = 'test.test@testTTAUT.org',
                           EmailEncodingKey = 'ISO-8859-1',
                           Alias = 'ttast',
                           TimeZoneSidKey = 'America/Los_Angeles',
                           LocaleSidKey = 'en_US',
                           LanguageLocaleKey = 'en_US',
                           ProfileId = p.Id,
                           ManagerId = m.Id);
        Users.add(u1);
        
        User u2 = new User(firstname = 'Test',
                           lastName = 'Test2',
                           email = 'test.test2@testTTAUT.org',
                           Username = 'test.test2@testTTAUT.org',
                           EmailEncodingKey = 'ISO-8859-1',
                           Alias = 'ttast',
                           TimeZoneSidKey = 'America/Los_Angeles',
                           LocaleSidKey = 'en_US',
                           LanguageLocaleKey = 'en_US',
                           ProfileId = p.Id,
                           ManagerId = m.Id);
        Users.add(u2);
        
        insert users;
       
        Account a = new Account(name='Test', OwnerId = users[0].id, BillingState = 'IL');
        accounts.add(a);
        
        Account a2 = new Account(name = 'Test2', OwnerId = users[0].id, BillingState = 'IL');
        accounts.add(a2);
        insert accounts;
        
        AccountTeamMember at2 = new AccountTeamMember(AccountId = accounts[0].Id, TeamMemberRole = 'Sales Rep', UserId = users[1].id);
        insert at2;
    }
    
    @isTest
    Public Static void AccountTeamInsertTest(){    
        List<User> users = new List<User>([Select Id FROM User WHERE Email =: 'test.test3@testTTAUT.org' OR Email =: 'test.test2@testTTAUT.org' OR Email =: 'test.test@testTTAUT.org']);
        List<Account> accounts = new List<Account>([SELECT Id, OwnerId, Name FROM Account WHERE Name =: 'Test' OR Name =: 'Test2']);
        List<Account> updateAccounts = new List<Account>();
        
        Account a1 = new Account(name='Test1', OwnerId = users[0].id, BillingState = 'IL');
        insert a1;
    }
    
    @isTest
    Public Static void AccountTeamChangesTest(){ 
        Profile P = [Select Id from Profile limit 1];
        
        User m1 = new User(firstname = 'Test',
                           lastName = 'Manager',
                           email = 'test.manager1@testTTAUT.org',
                           Username = 'test.manager1@testTTAUT.org',
                           EmailEncodingKey = 'ISO-8859-1',
                           Alias = 'ttast',
                           TimeZoneSidKey = 'America/Los_Angeles',
                           LocaleSidKey = 'en_US',
                           LanguageLocaleKey = 'en_US',
                           ProfileId = p.Id,
                           IsActive = FALSE);
        Insert m1;
        
        User u3 = new User(firstname = 'Test',
                           lastName = 'Test3',
                           email = 'test.test3@testTTAUT.org',
                           Username = 'test.test3@testTTAUT.org',
                           EmailEncodingKey = 'ISO-8859-1',
                           Alias = 'ttast',
                           TimeZoneSidKey = 'America/Los_Angeles',
                           LocaleSidKey = 'en_US',
                           LanguageLocaleKey = 'en_US',
                           ProfileId = p.Id,
                           ManagerId = m1.Id);
        insert u3;
        
        List<Account> accounts = new List<Account>([SELECT Id, OwnerId, Name FROM Account WHERE Name =: 'Test' OR Name =: 'Test2']);
        List<Account> updateAccounts = new List<Account>();
        
        if(accounts != NULL && !accounts.IsEmpty()){
            for(Account a : accounts){
                if(a.Name == 'Test'){
                    a.OwnerId = u3.Id;
                    updateAccounts.add(a);
                }
                else if (a.Name == 'Test2'){
                    a.Name = 'Test2a';
                    updateAccounts.add(a);
                }
            }
            
            if(updateAccounts != NULL && !updateAccounts.IsEmpty()){
                update updateAccounts;
            }
        }
        
    }
}