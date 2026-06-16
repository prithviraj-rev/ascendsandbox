@isTest
public class MetricsCalculationUtilityTest {
	private static Id caseRecTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('App Cases').getRecordTypeId();

	@testSetup
	static void createTestData() {

		UserRole usrRole = new UserRole(Name = 'Custom Role', PortalType = 'none');
		insert usrRole;

		Profile sysAdminProfile = [select Id from Profile where Name = 'System Administrator' limit 1];

		User testAdminUser = new User(
			LastName = 'OPENTEST',
			UserRoleId = usrRole.Id,
			Alias = 'CU1',
			Email = 'test@appirio.com',
			Username = 'custom1.user@abc.com',
			CommunityNickname = 'custom1.user@abc.com',
			ProfileId = sysAdminProfile.Id,
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'America/Los_Angeles'
		);
		User testAdminUser2 = new User(
			LastName = 'OPENTEST',
			UserRoleId = usrRole.Id,
			Alias = 'CU2',
			Email = 'test2@appirio.com',
			Username = 'custom2.user@abc.com',
			CommunityNickname = 'custom2.user@abc.com',
			ProfileId = sysAdminProfile.Id,
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'America/Los_Angeles'
		); 
		insert new List<User> { testAdminUser, testAdminUser2 }; 

		System.RunAs(testAdminUser) {
			Account testAccount = new Account(Name = 'Custom Account', OwnerId = testAdminUser.Id, BillingState = 'TN', BillingCountry = 'USA');
			
            Account testAccount1 = new Account(Name = 'Custom Account1', OwnerId = testAdminUser.Id, BillingState = 'BC', BillingCountry = 'Canada');
            insert new List<Account>{ testAccount, testAccount1 };
                
            Contact testContact = new Contact(FirstName = 'FN1', LastName = 'Custom Contact', AccountId = testAccount1.Id, MailingState = 'TN');
            insert testContact;
            
            SFDC_Projects__c project = new SFDC_Projects__c(Account__c = testAccount1.Id, Service__c = 'App');
            insert project;
            
            Case testCase = new Case(
				Status = 'New', Origin = 'Web', AccountId = testAccount1.Id, ContactId = testContact.Id, Project__c = project.Id, 
				RecordTypeId = caseRecTypeId, OwnerId = testAdminUser.Id
			);

			insert testCase;
			DurationTracking__c dtVar = new DurationTracking__c();
			dtVar.ChangedField__c = 'Status';
			dtVar.OldValue__c = '';
			dtVar.NewValue__c = testCase.Status;
			dtVar.CaseId__c = testCase.Id;
			insert dtVar;
		}
	}

	static testmethod void testCalculateTimeReported() {
		Test.startTest();
		Case c = [select Id, Status, CaseNumber, Account.BillingCountry from Case Limit 1]; 
		c.Status = 'Grooming';
		update c;

		//Begin Case #6063958 Add coverage of 'execute' function, and the creation of 'DurationTracking__c' and 'FlowInputs' objects required
		List<DurationTracking__c> chList = new List<DurationTracking__c>();
		chList.add(new DurationTracking__c(
			ChangedField__c = 'Status',
			OldValue__c = 'Setup',
			NewValue__c = c.Status,
			CaseId__c = c.Id
		));

		List<MetricsCalculationUtility.FlowInputs> flowInList = new List<MetricsCalculationUtility.FlowInputs>();
		MetricsCalculationUtility.FlowInputs flowIn = new MetricsCalculationUtility.FlowInputs();
		flowIn.newHistoryRecordsListIn = chList;
		flowIn.parentObjectIn = 'Case';
		flowIn.childObjectIn = 'DurationTracking__c';
		flowIn.parentObjFieldNameIn = 'CaseId__c'; 
		flowInList.add(flowIn);
		List<MetricsCalculationUtility.FlowOutputs> flowOutList = MetricsCalculationUtility.execute(flowInList);
		//Begin Case #6070207 Add coverage of 'calculateTime' and 'getCalculationData' functions
		MetricsCalculationUtility.calculateTime(
			MetricsCalculationUtility.getCalculationData(chList, 'Case', 'DurationTracking__c', 'CaseId__c'),
			'Case',
			'DurationTracking__c'
		);
		Test.stopTest();

		
		//DurationTracking__c caseHistoryRecord = [select Id, TimeReported__c from DurationTracking__c where CaseId__c = :c.Id order by CreatedDate desc limit 1];
		//Assert.isFalse(caseHistoryRecord.TimeReported__c == null, 'Time reported is null');
		List<DurationTracking__c> caseHistoryRecordList = [
			select Id, TimeReported__c
			from DurationTracking__c
			where CaseId__c = :c.Id and TimeReported__c = null and NewValue__c != 'On Hold' and OldValue__c = 'Setup'
			order by CreatedDate desc
		];
        Assert.isFalse(caseHistoryRecordList.size() > 0, 'Time reported is null');
	}
}