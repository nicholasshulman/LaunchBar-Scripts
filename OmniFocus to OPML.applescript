-- Indicative draft Ver 0.001

-- Saves anything selected in Omnifocus (Project or Context View) As an OPML
-- Including the following fields: DONE, NOTE, CONTEXT, PROJECT, START, DUE, COMPLETED, DURATION, FLAGGED}
-- Note that the whole sub-tree is copied, so only 'parent' elements need to be selected.

property pPROJECT : "project"
property pTASK : "task"
property pINBX_TASK : "inbox task"
property pITEM : "item"

property pOPMLHeadToExpand : "
<?xml version=\"1.0\" encoding=\"utf-8\"?>
<opml version=\"1.0\">
	<head>
	<title>Selected in OF</title>
	<expansionState>"
property pOPMLHeadFromExpand : "</expansionState>
	</head>
	<body>
 "

property pOPMLTail : "
	</body>
</opml>"

property pNodeStart : "<outline "
property pLeafClose : "/>"
property pParentClose : "</outline>"

on run
	set strOPML to MakeOPML(SelectedInOF())
	if strOPML ≠ "" then
		tell application "System Events"
			activate
			set oFile to choose file name with prompt "Save as OPML" default name "Untitled.opml" default location (path to desktop) as alias
		end tell
		WriteText2Path(strOPML, POSIX path of oFile)
	end if
end run

-- READ SELECTED OmniFocus CONTENT TREE(S) TO NESTED APPLESCRIPT LISTS - Ver.04

on SelectedInOF()
	tell application "OmniFocus"
		tell front window
			set blnContext to ((selected view mode identifier) is not equal to pPROJECT)
			
			repeat with oPanel in {content, sidebar}
				set lstNodes to value of (selected trees of oPanel where class of its value ≠ item)
				set lngNodes to count of lstNodes
				if lngNodes > 0 then exit repeat
			end repeat
			set blnAll to (lngNodes < 1)
			if blnAll then set lstNodes to value of (trees of content where class of its value ≠ item)
		end tell
		
		repeat with i from 1 to length of lstNodes
			tell item i of lstNodes
				if (its class) is not folder then
					if (number of tasks) > 0 then
						--set item i of lstNodes to {name, completed, my ListSubNodes(its tasks, blnContext, blnAll), note, "", "", start date, due date, completion date, estimated minutes, flagged}
						set item i of lstNodes to {name, completed, my ListSubNodes(its tasks, blnContext, blnAll), note, "", "", start date, due date, completion date, estimated minutes, flagged}
						
						
						
					else
						set item i of lstNodes to {name, completed, {}, note, "", "", start date, due date, completion date, estimated minutes, flagged}
					end if
				else
					if (number of projects) > 0 then
						set item i of lstNodes to {name, false, my ListSubNodes(its projects, blnContext, blnAll), note, "", "", missing value, missing value, missing value, missing value, false}
					else
						set item i of lstNodes to {name, false, {}, note, "", "", missing value, missing value, missing value, missing value, false}
					end if
				end if
			end tell
		end repeat
		
		return {lstNodes, blnContext}
	end tell
end SelectedInOF

on ListSubNodes(lstNodes, blnAll)
	using terms from application "OmniFocus"
		repeat with i from 1 to length of lstNodes
			tell item i of lstNodes
				
				set oProj to its containing project
				if oProj is not missing value then
					set strProject to name of oProj
				else
					set strProject to ""
				end if
				
				set oContext to its context
				if oContext is not missing value then
					set strContext to name of oContext
				else
					set strContext to ""
				end if
				
				if (number of tasks) > 0 then
					set item i of lstNodes to {name, completed, my ListSubNodes(its tasks, blnAll), note, strProject, strContext, start date, due date, completion date, estimated minutes, flagged}
				else
					set item i of lstNodes to {name, completed, {}, note, strProject, strContext, start date, due date, completion date, estimated minutes, flagged}
				end if
			end tell
		end repeat
		return lstNodes
	end using terms from
end ListSubNodes


-- BUILD OPML

on MakeOPML({lstTasks, blnContext})
	if (length of lstTasks > 0) then
		
		set {lngIndex, strExpand, strOutline} to my Tasks2OPML(-1, lstTasks, tab)
		set strOPML to pOPMLHeadToExpand & strExpand & pOPMLHeadFromExpand & strOutline & pOPMLTail
		return strOPML
	end if
end MakeOPML

on Tasks2OPML(lngIndex, lstTasks, strIndent)
	set {strExpand, strOut} to {"", ""}
	repeat with oTask in lstTasks
		set {strName, blnDone, lstChiln, strNote, strProject, strContext, dteStart, dteDue, dteDone, lngMins, blnFlagged} to oTask
		
		if strNote ≠ "" then
			set strOut to strOut & pNodeStart & Attr("text", strName) & Attr("_note", strNote)
		else
			set strOut to strOut & pNodeStart & Attr("text", strName)
		end if
		
		if blnDone then if (dteDone is not missing value) then
			set strOut to strOut & Attr("_status", "checked") & Attr("Completed", short date string of dteDone & space & time string of dteDone)
		end if
		
		if strProject ≠ "" then set strOut to strOut & Attr("Project", strProject)
		if strContext ≠ "" then set strOut to strOut & Attr("Context", strContext)
		
		tell dteStart to if it is not missing value then set strOut to strOut & my Attr("Start", short date string & space & time string)
		tell dteDue to if it is not missing value then set strOut to strOut & my Attr("Due", short date string & space & time string)
		
		if lngMins > 0 then set strOut to strOut & Attr("Duration", ((lngMins / 60) as string) & "h")
		if blnFlagged then set strOut to strOut & Attr("Flagged", "2")
		
		set lngIndex to lngIndex + 1
		if (length of lstChiln > 0) then
			set strExpand to strExpand & "," & (lngIndex) as string
			set {lngIndex, strSubExpand, strSubOutln} to Tasks2OPML(lngIndex, lstChiln, strIndent & tab)
			if strSubExpand ≠ "" then set strExpand to strExpand & "," & strSubExpand
			set strOut to strOut & ">" & return & ¬
				strIndent & strSubOutln & return & ¬
				strIndent & pParentClose
		else
			set strOut to strOut & pLeafClose & return
		end if
	end repeat
	if strExpand begins with "," and length of strExpand > 1 then set strExpand to text 2 thru -1 of strExpand
	return {lngIndex, strExpand, strOut}
end Tasks2OPML

on Attr(strName, strValue)
	--strName & "=\"" & strValue & "\" "
	strName & "=\"" & attributeValue(strValue) & "\" "
end Attr

on WriteText2Path(strText, strPosixPath)
	set f to (POSIX file strPosixPath)
	open for access f with write permission
	write strText as «class utf8» to f
	close access f
end WriteText2Path

on attributeValue(str)
	set retVal to stringReplace("&", "&amp;", str)
	set retVal to stringReplace("\"", "&quot;", retVal)
	set retVal to stringReplace("<", "&lt;", retVal)
	set retVal to stringReplace(">", "&gt;", retVal)
	set retVal to stringReplace("
", "
", retVal)
	
	-- additions for all sorts of characters and umlauts
	set retVal to stringReplace("À", "&Agrave;", retVal)
	set retVal to stringReplace("Á", "&Aacute;", retVal)
	set retVal to stringReplace("Â", "&Acirc;", retVal)
	set retVal to stringReplace("Ã", "&Atilde;", retVal)
	set retVal to stringReplace("Ä", "&Auml;", retVal)
	set retVal to stringReplace("Å", "&Aring;", retVal)
	set retVal to stringReplace("Æ", "&AElig;", retVal)
	set retVal to stringReplace("Ç", "&Ccedil;", retVal)
	set retVal to stringReplace("È", "&Egrave;", retVal)
	set retVal to stringReplace("É", "&Eacute;", retVal)
	set retVal to stringReplace("Ê", "&Ecirc;", retVal)
	set retVal to stringReplace("Ë", "&Euml;", retVal)
	set retVal to stringReplace("Ì", "&Igrave;", retVal)
	set retVal to stringReplace("Í", "&Iacute;", retVal)
	set retVal to stringReplace("Î", "&Icirc;", retVal)
	set retVal to stringReplace("Ï", "&Iuml;", retVal)
	set retVal to stringReplace("Ð", "&ETH;", retVal)
	set retVal to stringReplace("Ñ", "&Ntilde;", retVal)
	set retVal to stringReplace("Ò", "&Ograve;", retVal)
	set retVal to stringReplace("Ó", "&Oacute;", retVal)
	set retVal to stringReplace("Ô", "&Ocirc;", retVal)
	set retVal to stringReplace("Õ", "&Otilde;", retVal)
	set retVal to stringReplace("Ö", "&Ouml;", retVal)
	set retVal to stringReplace("Ø", "&Oslash;", retVal)
	set retVal to stringReplace("Ù", "&Ugrave;", retVal)
	set retVal to stringReplace("Ú", "&Uacute;", retVal)
	set retVal to stringReplace("Û", "&Ucirc;", retVal)
	set retVal to stringReplace("Ü", "&Uuml;", retVal)
	set retVal to stringReplace("Ý", "&Yacute;", retVal)
	set retVal to stringReplace("Þ", "&THORN;", retVal)
	set retVal to stringReplace("à", "&agrave;", retVal)
	set retVal to stringReplace("á", "&aacute;", retVal)
	set retVal to stringReplace("â", "&acirc;", retVal)
	set retVal to stringReplace("ã", "&atilde;", retVal)
	set retVal to stringReplace("ä", "&auml;", retVal)
	set retVal to stringReplace("å", "&aring;", retVal)
	set retVal to stringReplace("æ", "&aelig;", retVal)
	set retVal to stringReplace("ç", "&ccedil;", retVal)
	set retVal to stringReplace("è", "&egrave;", retVal)
	set retVal to stringReplace("é", "&eacute;", retVal)
	set retVal to stringReplace("ê", "&ecirc;", retVal)
	set retVal to stringReplace("ë", "&euml;", retVal)
	set retVal to stringReplace("ì", "&igrave;", retVal)
	set retVal to stringReplace("í", "&iacute;", retVal)
	set retVal to stringReplace("î", "&icirc;", retVal)
	set retVal to stringReplace("ï", "&iuml;", retVal)
	set retVal to stringReplace("ð", "&eth;", retVal)
	set retVal to stringReplace("ñ", "&ntilde;", retVal)
	set retVal to stringReplace("ò", "&ograve;", retVal)
	set retVal to stringReplace("ó", "&oacute;", retVal)
	set retVal to stringReplace("ô", "&ocirc;", retVal)
	set retVal to stringReplace("õ", "&otilde;", retVal)
	set retVal to stringReplace("ö", "&ouml;", retVal)
	set retVal to stringReplace("ø", "&oslash;", retVal)
	set retVal to stringReplace("ù", "&ugrave;", retVal)
	set retVal to stringReplace("ú", "&uacute;", retVal)
	set retVal to stringReplace("û", "&ucirc;", retVal)
	set retVal to stringReplace("ü", "&uuml;", retVal)
	set retVal to stringReplace("ý", "&yacute;", retVal)
	set retVal to stringReplace("þ", "&thorn;", retVal)
	set retVal to stringReplace("ÿ", "&yuml;", retVal)
	set retVal to stringReplace("ß", "&szlig;", retVal)
	
	return retVal
end attributeValue

on stringReplace(find, replace, subject)
	considering case
		
		set prevTIDs to text item delimiters of AppleScript
		set text item delimiters of AppleScript to find
		set subject to text items of subject
		
		set text item delimiters of AppleScript to replace
		set subject to "" & subject
		set text item delimiters of AppleScript to prevTIDs
		
	end considering
	
	return subject
end stringReplace