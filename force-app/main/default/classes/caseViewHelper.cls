/*
Ascend Technologies MS Case View
*/

public with sharing class caseViewHelper {
    public caseViewHelper() {}

    
    public static map<string, list<string>> getPicklistOptions(){
        map<string, list<string>> picklistOptions = new map<string, list<string>>();
        pickListOptions.put('Priority', picklistLabels(Case.priority.getDescribe()));
        pickListOptions.put('Impact', picklistLabels(Case.Impact__c.getDescribe()));
        pickListOptions.put('Status', picklistLabels(Case.status.getDescribe()));
        pickListOptions.put('reviewed', new list<string>{'Yes','No'});
        
       return picklistOptions;
    }


    public static list<string> picklistLabels(Schema.DescribeFieldResult fieldDescribe){
        list<string> labels = new list<string>();
        List<Schema.PicklistEntry> ple = fieldDescribe.getPicklistValues();
		for( Schema.PicklistEntry pickListVal : ple){
			labels.add(pickListVal.getLabel());
		}
        labels.sort();
        return labels;
    }


    @AuraEnabled 
    public static void caseReviewCheck(id reviewId, id caseId){
        Case c = [select id, lastmodifieddate from case where id=:caseId];
        Review__c rev = [select id, name, first_reviewed_case__c from review__c where id=:reviewId];
        if (rev.first_reviewed_case__c==null){
            rev.first_reviewed_case__c = c.lastModifieddate;
            update rev;
        }
    }

    @AuraEnabled (Cacheable=false)
    public static PageData getCases(Id reviewId){
        //incorporate fields from fieldsets into query via combined set
        pageData pd = new pageData();
        Review__c rev = [select id, name, first_reviewed_case__c from review__c where id=:reviewId];
        pd.firstReviewedCase = rev.first_reviewed_case__c;
        pd.reviewName = rev.Name;

        set<string> queryFields = new set<string>{'id', 'casenumber', 'subject', 'accountid', 'account.name', 'createddate', 'lastmodifieddate', 'ownerid', 'owner.name', 'isclosed', 'origin', 'status','impact__c', 'priority', 'queue_review_notes__c', 'current_review_notes__c', 'due_date__c', 'loe_estimate__c'};
        for (fieldWrapper fw: pd.editFields){
            queryFields.add(fw.fieldName.toLowerCase());
        }
        for (fieldWrapper fw: pd.cardFields){
            queryFields.add(fw.fieldName.toLowerCase());
        }
        list<string> listFields = new list<string>(queryFields);
        system.debug(json.serializepretty(listFields));
        string rId = reviewId;
        string whereClause = ' where (isclosed=false or (isclosed=true and lastmodifieddate  = LAST_N_DAYS:5)) and (not subject like \'Support Coordination - %\') ';
        //string soql = 'select ' + string.join(listFields,', ') + ' from case ' + whereClause + ' order by caseNumber desc LIMIT 100';
        string soql = 'select (select ' + string.join(listFields,', ') + ' from cases__r ' + whereClause + ' order by caseNumber desc) from Review__c where id=:rId';
        system.debug(soql);
        list<review__c> reviewCases = database.query(soql);

        list<case> casePool = reviewCases[0].Cases__r;
        //[select id, casenumber, description, subject, accountId, account.name, priority, status, origin, createddate, lastmodifieddate, ownerId, owner.name, isClosed from case order by caseNumber desc];
        set<string> devs = new set<string>();
        for (case c:casePool){
            caseWrapper cw = new caseWrapper(c);
            cw.reviewed = (pd.firstReviewedCase!=null && c.lastModifiedDate>pd.firstReviewedCase)?'Yes':'No';

            
            pd.casePool.add(cw);
            devs.add(c.owner.Name);
        }
        list<string> devList = new list<string>(devs);
        devList.sort();
        pd.picklists.put('ownerName', devList);
        for (integer i=0;i<devList.size();i++){
            for (caseWrapper c:pd.casePool){
                if (c.ownerName==devList[i]){
                    c.ownerSequence=i;
                }
            }
        }
        //system.debug(JSON.serialize(pd));
        return pd;
    }


    public static list<fieldWrapper> getCaseViewEditDetailFields() {
        list<fieldWrapper> fw = new list<fieldWrapper>();
        for (Schema.FieldSetMember f:SObjectType.Case.FieldSets.CaseViewEditDetail.getFields()){
            fw.add(new fieldWrapper(f));
        }
        return fw;
    }
    public static list<fieldWrapper> getCaseViewSummaryFields() {
        list<fieldWrapper> fw = new list<fieldWrapper>();
        for (Schema.FieldSetMember f:SObjectType.Case.FieldSets.CaseViewCard.getFields()){
            fw.add(new fieldWrapper(f));
        }
        return fw;
    }
    
    @AuraEnabled 
    public static void makeChatter(id caseId, string chatter){
        if (chatter!=''){
            FeedItem feed = new FeedItem();
            feed.ParentId =  caseId;
            feed.Body = 'Review Update: ' + chatter;
            insert feed;
        }
    }

    public class fieldWrapper {
        @AuraEnabled public string label {get;set;}
        @AuraEnabled public string fieldName {get;set;}
        @AuraEnabled public string fieldType {get;set;}
        @AuraEnabled public boolean required {get;set;}
        @AuraEnabled public string width {get{return (this.fieldType=='TEXTAREA')?'12-of-12':'6-of-12';} set;}

        public fieldWrapper(Schema.FieldSetMember f){
            this.label = f.Label;
            this.fieldName = f.fieldPath;
            this.fieldType = f.type.tostring();
            this.required = f.required;
//            {"dbRequired":false,"fieldPath":"Type","label":"Case Type","required":false,"type":"picklist","typeApex":"PICKLIST"}

        }
    }

    public class pageData {
        @AuraEnabled public list<caseWrapper> casePool {get;set;}
        @auraEnabled public map<string, list<string>> picklists {get;set;}
        @auraEnabled public date startDate {get;set;}
        @auraEnabled public date endDate {get;set;}
        @auraEnabled public datetime lastRefresh {get;set;}
        @auraEnabled public list<fieldWrapper> editFields {get;set;}
        @auraEnabled public list<fieldWrapper> cardFields {get;set;}
        @auraEnabled public datetime firstReviewedCase {get;set;}
        @auraEnabled public string reviewName {get;set;}

        public pageData(){
            this.casePool = new list<caseWrapper>();
            this.picklists = getPicklistOptions();
            this.endDate = date.today();
            this.startDate = this.endDate.addDays(-14);
            this.lastRefresh = datetime.now();
            this.editFields = getCaseViewEditDetailFields();
            this.cardFields = getCaseViewSummaryFields();
        }
    }

    public class caseWrapper {
        @AuraEnabled public Id caseId{get;set;}
        @AuraEnabled public Case wrappedCase{get;set;}
        @AuraEnabled public string caseLink{get;set;}
        @AuraEnabled public string CaseNumber {get;set;}
        @AuraEnabled public string customerName {get;set;}
        @AuraEnabled public string Subject {get;set;}
        @AuraEnabled public string Status {get;set;}
        @AuraEnabled public string Origin {get;set;}
        @AuraEnabled public string Priority {get;set;}
        @AuraEnabled public string Impact {get;set;}
        @AuraEnabled public string currentReviewNotes {get;set;}
        @AuraEnabled public string reviewNotes {get;set;}
        @AuraEnabled public date dueDate {get;set;}
        @AuraEnabled public Decimal LOE {get;set;}
        
        @AuraEnabled public date createdDate {get;set;}
        @AuraEnabled public datetime lastModifiedDate {get;set;}
        @AuraEnabled public string ownerName {get;set;}
        @AuraEnabled public string ownerInitials {get;set;}
        @AuraEnabled public integer ownerSequence {get;set;}

        @AuraEnabled public Id ownerId {get;set;}
        @AuraEnabled public boolean queueOwned {get;set;}
        @AuraEnabled public string ownershipIcon {get;set;}
        @AuraEnabled public boolean isClosed {get;set;}
        @AuraEnabled public integer version {get;set;}
        @AuraEnabled public string reviewed {get;set;}
        


        public caseWrapper(case c){
            this.wrappedCase = c;
            this.caseId = c.Id;
            this.caseLink = '/' + c.Id;
            this.customerName = c.account.Name;
            this.ownerName = c.Owner.Name;
            this.ownerInitials='';
            this.ownerSequence = 0;

            this.caseNumber = c.CaseNumber;
            this.subject = c.subject;
            this.origin = c.origin;
            this.status = c.status;
            this.priority = c.Priority;
            this.impact = c.Impact__c;
            this.currentReviewNotes = c.current_review_notes__c;
            this.reviewNotes = c.Queue_Review_Notes__c;
            this.dueDate = c.Due_Date__c;
            this.LOE = c.LOE_Estimate__c;
            this.createdDate = c.CreatedDate?.Date();
            this.lastModifiedDate = c.LastModifiedDate;
            this.ownerId = c.ownerId;
            this.isClosed = c.isClosed;
            
            string sOwnerId = c.ownerId;
            this.queueOwned = (this.ownerId==null)?false:sOwnerId.startsWith('00G');
            this.ownershipIcon = this.queueOwned?'utility:people':'utility:questions_and_answers';
            this.version=0;
            string oname = (this.ownerName!=null)?this.ownerName:'';
            for (string n:oname.split(' ')){
                this.ownerInitials+=n.left(1).toUpperCase();
            }
            this.reviewed='No';
        }
        
    }

}