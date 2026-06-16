({
    getPrototypes : function(component) {
        var action = component.get("c.getPrototypes");
        action.setParams({"resource":null});
        action.setCallback(this, function(a) {
            var prototypes = a.getReturnValue();
            //console.log(prototypes);
            component.set("v.prototypes", prototypes);
        });
        $A.enqueueAction(action);
    },
    getProjectTree : function(component) {
        var action = component.get("c.getProjectTree");
        action.setParams({"resource":null});
        action.setCallback(this, function(a) {
            var projectTree = a.getReturnValue();
            console.log("Projects");
            console.log(projectTree);
            component.set("v.projectTree", projectTree);
        });
        $A.enqueueAction(action);
    },
    getTeamTree : function(component) {
        var action = component.get("c.getTeamProjectTree");
        action.setParams({"resource":null});
        action.setCallback(this, function(a) {
            var activeResourceSections = new Array();
            var activeSections = new Array();
            var teamTree = a.getReturnValue();
            console.log("Team");
            console.log(teamTree);
            if (teamTree!=null){
                component.set("v.teamTree", teamTree.TeamTreeItems);
                component.set("v.delegatePermission", teamTree.delegatePermission);
                for(var x in teamTree.TeamTreeItems){
                    var resId;
                    
                    //clientSide sort is too slow
                    //sort projects and assignments.
                    /*
                    teamTree.TeamTreeItems[x].Projects.sort((a,b) => (a.Name > b.Name)?1:-1);
                    for (var y in teamTree.TeamTreeItems[x].Projects){
                        teamTree.TeamTreeItems[x].Projects[y].ProjectLines.sort((a,b) => (a.Name > b.Name)?1:-1);
                        teamTree.TeamTreeItems[x].Projects[y].AssignmentLines.sort((a,b) => (a.Name > b.Name)?1:-1);
                    }
                    */
                    if(teamTree.TeamTreeItems[x].isMe){
                        component.set("v.projectTree", teamTree.TeamTreeItems[x].Projects);
                        var projectTree = teamTree.TeamTreeItems[x].Projects;
                        component.set("v.activeSections", teamTree.TeamTreeItems[x].ProjectSections);
                    } else {
                        resId = teamTree.TeamTreeItems[x].treeName;
                        if (!activeResourceSections.includes(resId)){
                            console.log('open resource ' + resId);
                            activeResourceSections.push(resId);
                        }
                    }
                }
            }
            component.set("v.activeResourceSections", activeResourceSections);
        });
        $A.enqueueAction(action);
    }
    
})