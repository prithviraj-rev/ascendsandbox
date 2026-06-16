/******************************************************************************
// Summary:         The class controller for rprfDailyAssignmentsBuilder LWC component
// Test Class:      RPRFDailyAssignmentBuilderControllerTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 05/30/2024 - created
*******************************************************************************/

public with sharing class RPRFDailyAssignmentsBuilderController implements Callable
{
    private Object getAssignment(ID assignmentId) {
        return RPRFAssignmentService.getInstance().getAssignment(assignmentId);
    }

    private Object rebuildDailyAssignments(ID assignmentId, Boolean dailyAssignments, Boolean actualHours, Boolean projectedHours) {
        if(dailyAssignments == true) {
            RPRFAssignmentService.getInstance().recalculateDailyAssignments(assignmentId, actualHours, projectedHours);
        }else {
            if(actualHours == true) RPRFAssignmentService.getInstance().recalculateActualHours(assignmentId);
            if(projectedHours == true) RPRFAssignmentService.getInstance().recalculateProjectedHours(assignmentId);
        }
        return null;
    }
    
    /*************************** CALLABLE SECTION **********************************/

	public Object call(String actionName, Map<String, Object> params) 
	{
		switch on actionName {
            when 'getAssignment' {
                return getAssignment((ID)params.get('assignmentId'));
			}

			when 'rebuildDailyAssignments' {
                return rebuildDailyAssignments((ID)params.get('assignmentId'), (Boolean)params.get('dailyAssignments'), (Boolean)params.get('actualHours'), (Boolean)params.get('projectedHours'));
			}

		  	when else {
				throw new AuraHelper.AuraException('Invalid action name.');
		  	}
		}
	}
}