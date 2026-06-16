trigger Assignment_DailyAssignment on SFDC_Assignment__c (after insert, after update) {
    /*BusinessHours bh=new BusinessHours();
    bh = [select id from businesshours where isdefault= true];
    SFDC_Projects__c dProj = new SFDC_Projects__c();
    if(!test.isRunningTest())dProj = [Select Id from SFDC_Projects__c where name='Doextra Internal' limit 1][0];
    list<Daily_Assignment__c> lda=new list<Daily_Assignment__c>();
    set<Id> st=new set<Id>();
    for(SFDC_Assignment__c assign:trigger.new){
         if(dProj==null || assign.Projects__c!=dProj.Id){
            Date d=assign.First_Work_Day__c;
            DateTime dt= datetime.newInstance(d.year(),d.month(),d.day());
            integer i=assign.Work_Days_Between__c.intvalue();
            integer i2=0;
            while(i2<i){
                if(Math.mod((date.newinstance(1985, 6, 24)).daysBetween(d),7)<5){
                    if(businesshours.add(bh.id, dt, 1).day()==dt.day()){
                        lda.add(new Daily_Assignment__c(Name='1', Contact__c=assign.Resource__c,Assignment__c=assign.Id, Daily_Date__c=d));
                        i2++;
                    }else{
                        i2++;
                    }
                }
                d=d.adddays(1);
                dt=dt.adddays(1);
            }
            st.add(assign.Id);
        }
    }
    if(trigger.isUpdate){
        list<Daily_Assignment__c> delda=[Select Id From Daily_Assignment__c where Assignment__c IN:st];
        delete delda;
    }
    if(lda.size()>0){
        insert lda;
    }*/
    if(trigger.isInsert){
        ResourceAssignmentShare ras = new ResourceAssignmentShare();
        ras.execute(null);
    }
}