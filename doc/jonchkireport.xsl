<xsl:stylesheet id="jonchkistyle" version="1.0">
<xsl:output method="html" indent="no" omit-xml-declaration="yes" encoding="UTF-8"/>

<xsl:template match="/">
	<html>
		<xsl:comment>XSLT stylesheet used to transform this file:  jonchkireport.xsl</xsl:comment>
		<head>
			<title>Jonchki report for <xsl:call-template name="project_gmav"/></title>
			<style type="text/css">
.global {
	background-color: darkseagreen;
	font-family: sans-serif;
	font-size: medium;
}

.dependency_tree_indent {
	display: inline;
	font-weight: bold;
	font-family: monospace;
}

#system,
#project,
#artifacts,
#statistics,
#main {
	display: block;
	border-width: medium;
	border-style: inset;
	border-color: green;
	border-radius: 1em;
	padding: 1em;
	margin-bottom: 1em;
	background-color: lemonchiffon;
}

#platform,
#system_configuration,
#repository,
#artifacts_overview,
#artifact_details,
#artifact_dependencies,
#statistics_repository {
	display: table;
	padding: 1em;
}

#platform_caption,
#system_configuration_caption,
#repository_caption,
#artifacts_overview_caption,
#artifact_details_caption,
#artifact_dependencies_caption,
#statistics_caption {
	display: table-caption;
}

#platform_content_body,
#system_configuration_content_body,
#repository_content_body,
#artifacts_overview_content_body,
#artifact_details_content_body,
#artifact_dependencies_content_body,
#statistics_repository_content_body {
	border-width: medium;
	border-style: solid;
	border-color: black;
	padding: 0.5em;
}

#platform_content_row,
#system_configuration_content_row,
#repository_content_row,
#artifacts_overview_content_row,
#artifact_details_content_row,
#artifact_dependencies_content_row,
#statistics_repository_content_row {
	display: table-row;
}

#platform_content_key,
#system_configuration_content_key,
#repository_content_key,
#artifacts_overview_content_key,
#artifact_details_content_key,
#artifact_dependencies_content_key,
#statistics_repository_content_key {
	display: table-cell;
	font-weight: bold;
	padding-right: 1em;
}

#platform_content_value,
#system_configuration_content_value,
#repository_content_value,
#artifacts_overview_content_value,
#artifact_details_content_value,
#artifact_dependencies_content_value,
#statistics_repository_content_value {
	display: table-cell;
	padding-right: 1em;
}

#repositories, #artifact_chapter {
	display: block;
	margin: 1em;
}

#repositories_caption, #artifacts_caption, #artifact_caption {
	font-weight: bold;
	font-size: large;
}

#vcs_id {
	font-family: monospace;
}
			</style>
		</head>
		<body class="global">
		<xsl:apply-templates select="JonchkiReport"/>
		</body>
	</html>
</xsl:template>


<xsl:template name="project_gmav">
	<xsl:value-of select="concat(/JonchkiReport/artifacts/artifact[@id='0']/info/group, '.', /JonchkiReport/artifacts/artifact[@id='0']/info/module, '-', /JonchkiReport/artifacts/artifact[@id='0']/info/artifact, '-', /JonchkiReport/artifacts/artifact[@id='0']/info/version)"/>
</xsl:template>


<xsl:template name="simple_url_link">
	<xsl:param name="url"/>
	<xsl:element name="a">
		<xsl:attribute name="href"><xsl:value-of select="$url"/></xsl:attribute>
		<xsl:value-of select="$url"/>
	</xsl:element>
</xsl:template>



<xsl:template name="platform">
	<div id="platform">
		<div id="platform_caption">Platform</div>
		<div id="platform_content_body">
			<div id="platform_content_row">
				<td></td>
				<div id="platform_content_key">host</div>
				<div id="platform_content_key">override</div>
			</div>
			<div id="platform_content_row">
				<div id="platform_content_key">CPU architecture</div>
				<div id="platform_content_value"><xsl:value-of select="system/platform/host/cpu_architecture"/></div>
				<div id="platform_content_value"><xsl:value-of select="system/platform/override/cpu_architecture"/></div>
			</div>
			<div id="platform_content_row">
				<div id="platform_content_key">distribution ID</div>
				<div id="platform_content_value"><xsl:value-of select="system/platform/host/distribution_id"/></div>
				<div id="platform_content_value"><xsl:value-of select="system/platform/override/distribution_id"/></div>
			</div>
			<div id="platform_content_row">
				<div id="platform_content_key">distribution version</div>
				<div id="platform_content_value"><xsl:value-of select="system/platform/host/distribution_version"/></div>
				<div id="platform_content_value"><xsl:value-of select="system/platform/override/distribution_version"/></div>
			</div>
		</div>
	</div>
</xsl:template>



<xsl:template name="system">
	<div id="system">
		<a name="system"/>
		<h2>System Information</h2>
		<xsl:call-template name="platform"/>
	</div>
</xsl:template>



<xsl:template name="project_configuration">
	<h2>Project configuration</h2>
	<div id="repositories_caption">Repositories</div>
	<div id="repositories">
		<xsl:for-each select="configuration/project/repositories/repository">
			<xsl:sort select="@idx" order="ascending" data-type="number"/>
			<div id="repository">
				<div id="repository_caption">Repository <xsl:value-of select="concat('&quot;', id, '&quot;')"/></div>
				<div id="repository_content_body">
					<div id="repository_content_row">
						<div id="repository_content_key">type</div>
						<div id="repository_content_value"><xsl:value-of select="type"/></div>
					</div>
					<div id="repository_content_row">
						<div id="repository_content_key">cacheable</div>
						<div id="repository_content_value"><xsl:value-of select="cacheable"/></div>
					</div>
					<div id="repository_content_row">
						<div id="repository_content_key">rescan</div>
						<div id="repository_content_value"><xsl:value-of select="rescan"/></div>
					</div>
					<div id="repository_content_row">
						<div id="repository_content_key">root</div>
						<div id="repository_content_value"><xsl:value-of select="root"/></div>
					</div>
					<div id="repository_content_row">
						<div id="repository_content_key">versions</div>
						<div id="repository_content_value"><xsl:value-of select="versions"/></div>
					</div>
					<div id="repository_content_row">
						<div id="repository_content_key">config</div>
						<div id="repository_content_value"><xsl:value-of select="config"/></div>
					</div>
					<div id="repository_content_row">
						<div id="repository_content_key">artifact</div>
						<div id="repository_content_value"><xsl:value-of select="artifact"/></div>
					</div>
				</div>
			</div>
		</xsl:for-each>
	</div>
	<h3>Policies</h3>
</xsl:template>


<xsl:template name="project">
	<div id="project">
		<a name="project"/>
		<xsl:call-template name="project_configuration"/>
	</div>
</xsl:template>



<xsl:template name="artifact_tree">
	<xsl:param name="start_id"/>
	<xsl:param name="indent"/>
	<xsl:for-each select="/JonchkiReport/artifacts/artifact[parent=$start_id]">
		<xsl:sort select="@id" order="ascending" data-type="number"/>
		<div id="artifact_dependencies_content_row">
			<div id="artifact_dependencies_content_value"><div class="dependency_tree_indent"><xsl:value-of select="$indent"/></div><xsl:value-of select="info/group"/></div>
			<div id="artifact_dependencies_content_value"><xsl:value-of select="info/module"/></div>
			<div id="artifact_dependencies_content_value"><xsl:value-of select="info/artifact"/></div>
			<div id="artifact_dependencies_content_value"><xsl:value-of select="info/version"/></div>
			<div id="artifact_dependencies_content_value"><div id="vcs_id"><xsl:value-of select="info/vcs_id"/></div></div>
			<div id="artifact_dependencies_content_value"><xsl:value-of select="repositories/configuration"/></div>
			<div id="artifact_dependencies_content_value"><xsl:value-of select="repositories/artifact"/></div>
		</div>
		<xsl:call-template name="artifact_tree">
			<xsl:with-param name="start_id" select="@id"/>
			<xsl:with-param name="indent" select="concat($indent,'-')"/>
		</xsl:call-template>
	</xsl:for-each>
</xsl:template>



<xsl:template name="artifacts">
	<div id="artifacts">
		<a name="artifacts"/>
		<div id="artifacts_caption">Artifacts</div>

		<!-- First show a quick overview of all artifacts. -->
		<div id="artifacts_overview">
			<div id="artifacts_overview_caption">Overview</div>
			<div id="artifacts_overview_content_body">
				<div id="artifacts_overview_content_row">
					<div id="artifacts_overview_content_key">Group</div>
					<div id="artifacts_overview_content_key">Module</div>
					<div id="artifacts_overview_content_key">Artifact</div>
					<div id="artifacts_overview_content_key">Version</div>
					<div id="artifacts_overview_content_key">VCS version</div>
					<div id="artifacts_overview_content_key">Config repo</div>
					<div id="artifacts_overview_content_key">Artifact repo</div>
				</div>
				<xsl:call-template name="artifact_tree">
					<xsl:with-param name="start_id" select="'none'"/>
					<xsl:with-param name="indent" select="''"/>
				</xsl:call-template>
			</div>
		</div>

		<!-- Show each artifact in a detail view. -->
		<xsl:for-each select="artifacts/artifact">
			<xsl:sort select="@id" order="ascending" data-type="number"/>
			<div id="artifact_caption">Artifact <xsl:value-of select="concat(info/group,'.',info/module,'-',info/artifact)"/></div>
			<div id="artifact_chapter">
				<div id="artifact_details">
					<div id="artifact_details_caption">Details</div>
					<div id="artifact_details_content_body">
						<div id="artifact_details_content_row">
							<div id="artifact_details_content_key">Version</div>
							<div id="artifact_details_content_value"><xsl:value-of select="info/version"/></div>
						</div>
						<div id="artifact_details_content_row">
							<div id="artifact_details_content_key">VCS ID</div>
							<div id="artifact_details_content_value"><div id="vcs_id"><xsl:value-of select="info/vcs_id"/></div></div>
						</div>
						<div id="artifact_details_content_row">
							<div id="artifact_details_content_key">License</div>
							<div id="artifact_details_content_value"><xsl:value-of select="info/license"/></div>
						</div>
						<div id="artifact_details_content_row">
							<div id="artifact_details_content_key">Author</div>
							<div id="artifact_details_content_value"><xsl:value-of select="info/author_name"/></div>
						</div>
						<div id="artifact_details_content_row">
							<div id="artifact_details_content_key">URL</div>
							<div id="artifact_details_content_value">
								<xsl:call-template name="simple_url_link"><xsl:with-param name="url" select="info/author_url"/></xsl:call-template>
							</div>
						</div>
					</div>
				</div>
				<div id="artifact_dependencies">
					<div id="artifact_dependencies_caption">Dependencies</div>
					<div id="artifact_dependencies_content_body">
						<div id="artifact_dependencies_content_row">
							<div id="artifact_dependencies_content_key">Group</div>
							<div id="artifact_dependencies_content_key">Module</div>
							<div id="artifact_dependencies_content_key">Artifact</div>
							<div id="artifact_dependencies_content_key">Version</div>
							<div id="artifact_dependencies_content_key">VCS version</div>
							<div id="artifact_dependencies_content_key">Config repo</div>
							<div id="artifact_dependencies_content_key">Artifact repo</div>
						</div>
						<xsl:choose>
							<xsl:when test="count(/JonchkiReport/artifacts/artifact[parent=current()/@id])=0">
								None.
							</xsl:when>
							<xsl:otherwise>
								<xsl:call-template name="artifact_tree">
									<xsl:with-param name="start_id" select="@id"/>
									<xsl:with-param name="indent" select="''"/>
								</xsl:call-template>
							</xsl:otherwise>
						</xsl:choose>
					</div>
				</div>
			</div>
		</xsl:for-each>
	</div>
</xsl:template>


<xsl:template name="statistics">
	<div id="statistics">
		<a name="statistics"/>
		<div id="statistics_caption">Statistics</div>

		<div id="statistics_repository">
			<div id="statistics_repository_caption">Repositories</div>
			<div id="statistics_repository_content_body">
				<div id="statistics_repository_content_row">
					<div id="statistics_repository_content_key">ID</div>
					<div id="statistics_repository_content_key">Config Requests OK</div>
					<div id="statistics_repository_content_key">Config Requests Error</div>
					<div id="statistics_repository_content_key">Artifact Requests OK</div>
					<div id="statistics_repository_content_key">Artifact Requests Error</div>
					<div id="statistics_repository_content_key">Served Config</div>
					<div id="statistics_repository_content_key">Served Config Hash</div>
					<div id="statistics_repository_content_key">Served Artifact</div>
					<div id="statistics_repository_content_key">Served Artifact Hash</div>
				</div>
				<xsl:for-each select="statistics/repository">
					<div id="statistics_repository_content_row">
						<div id="statistics_repository_content_value"><xsl:value-of select="@id"/></div>
						<div id="statistics_repository_content_value"><xsl:value-of select="requests/configuration/success"/></div>
						<div id="statistics_repository_content_value"><xsl:value-of select="requests/configuration/error"/></div>
						<div id="statistics_repository_content_value"><xsl:value-of select="requests/artifact/success"/></div>
						<div id="statistics_repository_content_value"><xsl:value-of select="requests/artifact/error"/></div>
						<div id="statistics_repository_content_value"><xsl:value-of select="served_bytes/configuration"/></div>
						<div id="statistics_repository_content_value"><xsl:value-of select="served_bytes/configuration_hash"/></div>
						<div id="statistics_repository_content_value"><xsl:value-of select="served_bytes/artifact"/></div>
						<div id="statistics_repository_content_value"><xsl:value-of select="served_bytes/artifact_hash"/></div>
					</div>
				</xsl:for-each>
			</div>
		</div>
	</div>
</xsl:template>


<xsl:template match="JonchkiReport">
	<div id="main">
		<h1>Jonchki report for <xsl:call-template name="project_gmav"/></h1>

		<!-- Show a table of contents. -->
		<h2><a name="toc">Table of Contents</a></h2>
		<b><big><a href="#system">System Information</a></big></b><br/>
		<b><big><a href="#project">Project Configuration</a></big></b><br/>
		<b><big><a href="#artifacts">Artifacts</a></big></b><br/>
		<b><big><a href="#statistics">Statistics</a></big></b><br/>
	</div>
	
	<xsl:call-template name="system"/>
	<xsl:call-template name="project"/>
	<xsl:call-template name="artifacts"/>
	<xsl:call-template name="statistics"/>
</xsl:template>

</xsl:stylesheet>
