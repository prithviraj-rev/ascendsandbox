@isTest
public class populateCaseTimeOpenBatchTest {
	@testSetup
	static void setup() {
		Account account = new Account();
		account.Name = 'Test Account';
		account.BillingCountry = 'USA';
		insert account;

		Case caseVar1 = new Case();
		caseVar1.OwnerId = UserInfo.getUserId();
		caseVar1.Status = 'On Hold';
		caseVar1.AccountId = account.id;
		caseVar1.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('App_Cases').getRecordTypeId();
		insert caseVar1;

		Case caseVar2 = new Case();
		caseVar2.OwnerId = UserInfo.getUserId();
		caseVar2.Status = 'Grooming';
		caseVar2.AccountId = account.id;
		caseVar2.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('App_Cases').getRecordTypeId();
		insert caseVar2;
	}

	@isTest
	static void test() {
		Test.startTest();
		PopulateCaseTimeOpenJob m = new PopulateCaseTimeOpenJob();
		String crh = '0 0 21 1/1 * ? *';
		String jobID = System.schedule('PopulateCaseTimeOpenJob', crh, m);
		Database.executeBatch(new populateCaseTimeOpenBatch());
		Test.stopTest();
		System.assertEquals(1, [select Id, State from CronTrigger where Id = :jobID].size(),'The job is completed'); //W-041359 - commented out

		//System.assertEquals(1, [select CaseId__c from DurationTracking__c where IsTimeSpentTracker__c = true].size());
	}
}