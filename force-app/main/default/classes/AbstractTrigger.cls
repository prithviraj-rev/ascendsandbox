/******************************************************************************
// Project:         Resource Planning and Revenue Forecasting
// Summary:         The class wrapper to SF object triggers
// Test Class:      AbstractTriggerTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 05/09/2024 - created
*******************************************************************************/

public virtual with sharing class AbstractTrigger 
{
    public static Boolean Disabled {get;set;}
    public Boolean getDisabled()
    {
    	return AbstractTrigger.Disabled;
    }

    public void execute()
    {
        if(this.getDisabled() == true) return;
        
        try
		{
	        if(Trigger.isbefore)
	        {
	            if(Trigger.isinsert)
	            {
	                beforeInsert(Trigger.new);
	            }
	            else if(Trigger.isupdate)
	            {
	                beforeUpdate(Trigger.new, Trigger.old);
	            }
	            else if(Trigger.isdelete)
	            {
	                beforeDelete(Trigger.old);
	            }
	        }else if(Trigger.isafter)
	        {
	            if(Trigger.isinsert) 
	            {
	                afterInsert(Trigger.new);
	            }
	            else if(Trigger.isupdate) 
	            {
	                afterUpdate(Trigger.new, Trigger.old);
	            }
	            else if(Trigger.isdelete)
	            {
	                afterDelete(Trigger.old);
	            }
	        }
		}catch(Exception ex)
		{
			for(sObject record : (Trigger.new != null ? Trigger.new : Trigger.old))
            	record.addError(String.valueOf(ex));
		}
    }
    
    public virtual void beforeInsert(List<SObject> records){}
    public virtual void afterInsert(List<SObject> records){}
    public virtual void beforeUpdate(List<SObject> records, List<SObject> oldRecords){}
    public virtual void afterUpdate(List<SObject> records, List<SObject> oldRecords){}
    public virtual void beforeDelete(List<SObject> records){}
    public virtual void afterDelete(List<SObject> records){}
}