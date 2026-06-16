@isTest
public class ResourceAssignmentShare_UT {

    public static testmethod void ResourceAssignmentShareTest(){
        Account a = new account(name='Test', BillingState = 'IL');
        insert a;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name='Resource'];
        
        Contact c = new Contact(LastName='Test',FirstName='Test', accountId=a.Id, RecordTypeId=lr[0].Id, Employment_Type__c='1099');
        User user1 = getPortalUser(null, true, c, a);
        SFDC_Projects__c proj = new SFDC_Projects__c(Account__c = a.Id,Project_Stage__c='Active');     
        insert proj;
        
        SFDC_Assignment__c sfa = new SFDC_Assignment__c(resource__c=c.Id, projects__c=proj.Id, Start_Date__c=date.today().addDays(-20), End_Date__c=date.today().addDays(20), Number_Of_Hours__c=10);
        insert sfa;
        
        ResourceAssignmentShare ras = new ResourceAssignmentShare();
		ras.execute(null);
        
    }
    public static User getPortalUser(User userWithRole, Boolean doInsert, Contact c, Account a) {

        /* Make sure the running user has a role otherwise an exception
           will be thrown. */
        if(userWithRole == null) {  
            if(UserInfo.getUserRoleId() == null) {
                UserRole r = new UserRole(name = 'TEST ROLE');
                Database.insert(r);
                userWithRole = new User(alias = 'hasrole', email='userwithrole@roletest1.com', userroleid = r.id,
                                    emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
                                    localesidkey='en_US', profileid = UserInfo.getProfileId(),
                                    timezonesidkey='America/Los_Angeles');
                Database.insert(userWithRole);
            } else {
                userWithRole = new User(Id = UserInfo.getUserId(), UserRoleId = UserInfo.getUserRoleId());
            }
            System.assert(userWithRole.userRoleId != null,
                          'This test requires the target org to have at least one UserRole created. Please create a user role in this organization and try again.');
        }
        System.runAs(userWithRole) {
            a.ownerId = userWithRole.Id;
            Database.update(a);
            Database.insert(c);
        }
        /* Get any profile for the given type.*/
        Profile p = [select id
                      from profile
                     where usertype = 'PowerCustomerSuccess' and Name Like 'Ascend%'
                     limit 1];  
        String testemail = 'puser000@amamama.com';
        User pu = new User(profileId = p.id, username = testemail, email = testemail,
                           emailencodingkey = 'UTF-8', localesidkey = 'en_US',
                           languagelocalekey = 'en_US', timezonesidkey = 'America/Los_Angeles',
                           alias='cspu', lastname='lastname', contactId = c.id,
                           managerId = UserInfo.getUserId());
        if(doInsert) {
            System.runAs(userWithRole) {
            	Database.insert(pu);
            }
        }
        return pu;
    }
}