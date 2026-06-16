trigger timecard_summary_assignment on SFDC_Timecard__c (before insert, before update) {
    //get assignments.
    set<Id> assignment = new set<Id>();
    for (SFDC_timecard__c tc:trigger.new){
        assignment.add(tc.assignment__c);
    }
    map<id, SFDC_Assignment__c> assMap = new map<id, SFDC_Assignment__c>([select id, Resource__c from SFDC_Assignment__c where id in: assignment ]);
    map<id,id> usersToQuery = new map<id,id>();
    date min=date.today().addyears(10);
    date max=date.today().addyears(-10);
    
    //get users via assignments
    for (SFDC_timecard__c tc:trigger.new){
        usersToQuery.put(assMap.get(tc.assignment__c).resource__c, tc.Id);
        if (tc.date__c<min){
            min = tc.date__c;
        } 
        if (tc.date__c>max){
            max = tc.date__c;
        }
    }
    list<Timecard_Summary__c> summariesToInsert = new list<Timecard_Summary__c>();
    list<SFDC_timecard__c>tcToReconcile = new list<SFDC_timecard__c>();
    list<Timecard_Summary__c> summaryPool = [select id, resource__c, start_date__c, end_date__c 
                                from timecard_summary__c 
                                where resource__c in:usersToQuery.keyset() ];
                                    //and start_date__c<=:min 
                                    //and end_date__c>=:max 
                                    //and status__c in ('New', 'Pending approval')

    for (SFDC_timecard__c tc:trigger.new){
        tc.Timecard_Summary__c=null;
        for(Timecard_Summary__c ts:SummaryPool){
            if (usersToQuery.containskey(ts.resource__c)
                && assMap.get(tc.assignment__c).resource__c==ts.Resource__c 
                && tc.date__c>=ts.start_date__c 
                && tc.date__c<=ts.end_date__c){

                tc.Timecard_summary__c = ts.Id;
            }
        }
        if (tc.Timecard_Summary__c==null){
            SFDC_Assignment__c res = assmap.get(tc.assignment__c);
            date startdate = tc.date__c;
            startdate = startdate.toStartOfMonth();
            date enddate = startdate.addMonths(1).toStartofMonth().addDays(-1);

            Timecard_Summary__c nts = null;
            for (Timecard_Summary__c ntx:summariesToInsert){
                if (ntx.resource__c ==  res.resource__c &&
                    ntx.start_date__c == startdate &&
                    ntx.end_date__c == enddate){
                            
                    nts=ntx;        
                }
            }
            if (nts == null){
                nts = new Timecard_Summary__c(resource__c=res.resource__c, 
                                                                start_date__c=startdate,
                                                                end_date__c=enddate,
                                                                status__c='New');
                summariesToInsert.add(nts);
            }
            tc.timecard_summary__r = nts;
            tcToReconcile.add(tc);
        }
    }
    if (summariesToInsert.size()>0){
        system.debug(summariesToInsert);
        insert summariesToInsert;
        for (SFDC_timecard__c tcx:tcToReconcile){
            tcx.timecard_summary__c = tcx.timecard_summary__r.id;
        }
    }
    
}