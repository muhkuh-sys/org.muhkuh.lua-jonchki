<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" indent="no" omit-xml-declaration="yes" encoding="UTF-8"/>

<xsl:template match="/">
	<html>
		<xsl:comment>XSLT stylesheet used to transform this file:  jonchkireport.xsl</xsl:comment>
		<head>
			<title>Jonchki Report</title>
			<style type="text/css">
.global {
	background-color: darkseagreen;
	font-family: sans-serif;
	font-size: medium;
}

#system, #project, #artifacts, #toc {
	display: block;
	border-width: medium;
	border-style: inset;
	border-color: green;
	border-radius: 1em;
	padding: 1em;
	margin-bottom: 1em;
	background-color: lemonchiffon;
}

#platform, #system_configuration, #repository, #artifacts_overview, #artifacts_details {
	display: table;
	padding: 1em;
}

#platform_caption, #system_configuration_caption, #repository_caption, #artifacts_overview_caption, ##artifacts_details_caption {
	display: table-caption;
	
}

#platform_content_body, #system_configuration_content_body, #repository_content_body, #artifacts_overview_content_body, #artifacts_details_content_body {
	border-width: medium;
	border-style: solid;
	border-color: black;
	padding: 0.5em;
}

#platform_content_row, #system_configuration_content_row, #repository_content_row, #artifacts_overview_content_row, #artifacts_details_content_row {
	display: table-row;
}

#platform_content_key, #system_configuration_content_key, #repository_content_key, #artifacts_overview_content_key, #artifacts_details_content_key {
	display: table-cell;
	font-weight: bold;
	padding-right: 1em;
}

#platform_content_value, #system_configuration_content_value, #repository_content_value, #artifacts_overview_content_value, #artifacts_details_content_value {
	display: table-cell;
	padding-right: 1em;
}

#repositories, #artifact_details {
	display: block;
	margin: 1em;
}

#repositories_caption, #artifacts_caption {
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


<xsl:template name="system_configuration">
	<div id="system_configuration">
		<div id="system_configuration_caption">System configuration</div>
		<div id="system_configuration_content_body">
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">work</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/work"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">cache</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/cache"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">cache_max_size</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/cache_max_size"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">depack</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/depack"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">install_base</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/install_base"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">install_lua_path</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/install_lua_path"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">install_lua_cpath</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/install_lua_cpath"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">install_shared_objects</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/install_shared_objects"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">install_doc</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/install_doc"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">install_dev</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/install_dev"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">install_dev_include</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/install_dev_include"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">install_dev_lib</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/install_dev_lib"/></div>
			</div>
			<div id="system_configuration_content_row">
				<div id="system_configuration_content_key">install_dev_cmake</div>
				<div id="system_configuration_content_value"><xsl:value-of select="system/configuration/install_dev_cmake"/></div>
			</div>
		</div>
	</div>
</xsl:template>


<xsl:template name="system">
	<div id="system">
		<a name="system"/>
		<xsl:call-template name="platform"/>
		<xsl:call-template name="system_configuration"/>
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
						<div id="repository_content_key">Type</div>
						<div id="repository_content_value"><xsl:value-of select="type"/></div>
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


<!--
<xsl:template name="artifact_tree">
	<table border="1" cellspacing="0" cellpadding="2">
	<xsl:for-each select="../artifact/@parent='0'">
		<xsl:sort select="@id" order="ascending" data-type="number"/>
	</xsl:for-each>
</xsl:template>
-->


<xsl:template name="artifacts">
	<div id="artifacts">
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
				</div>
				<xsl:for-each select="artifacts/artifact">
					<xsl:sort select="@id" order="ascending" data-type="number"/>
					<div id="artifacts_overview_content_row">
						<div id="artifacts_overview_content_value"><xsl:value-of select="info/group"/></div>
						<div id="artifacts_overview_content_value"><xsl:value-of select="info/module"/></div>
						<div id="artifacts_overview_content_value"><xsl:value-of select="info/artifact"/></div>
						<div id="artifacts_overview_content_value"><xsl:value-of select="info/version"/></div>
						<div id="artifacts_overview_content_value"><div id="vcs_id"><xsl:value-of select="info/vcs_id"/></div></div>
					</div>
				</xsl:for-each>
			</div>
		</div>

		<!-- Show each artifact in a detail view. -->
		<xsl:for-each select="artifacts/artifact">
			<xsl:sort select="@id" order="ascending" data-type="number"/>
			<div id="artifact_details">
				<div id="artifacts_details_caption">Artifact <xsl:value-of select="concat(info/group,'.',info/module,'-',info/artifact)"/></div>
				<div id="artifacts_details_content_body">
					<div id="artifacts_details_content_row">
						<div id="artifacts_details_content_key">Version</div>
						<div id="artifacts_details_content_value"><xsl:value-of select="info/version"/></div>
					</div>
					<div id="artifacts_details_content_row">
						<div id="artifacts_details_content_key">VCS ID</div>
						<div id="artifacts_details_content_value"><div id="vcs_id"><xsl:value-of select="info/vcs_id"/></div></div>
					</div>
					<div id="artifacts_details_content_row">
						<div id="artifacts_details_content_key">License</div>
						<div id="artifacts_details_content_value"><xsl:value-of select="info/license"/></div>
					</div>
					<div id="artifacts_details_content_row">
						<div id="artifacts_details_content_key">Author</div>
						<div id="artifacts_details_content_value"><xsl:value-of select="info/author_name"/></div>
					</div>
					<div id="artifacts_details_content_row">
						<div id="artifacts_details_content_key">URL</div>
						<div id="artifacts_details_content_value">
							<xsl:call-template name="simple_url_link"><xsl:with-param name="url" select="info/author_url"/></xsl:call-template>
						</div>
					</div>
				</div>
				<h4>Dependencies</h4>
			</div>
<!-- 
		<xsl:call-template name="artifact_tree">
			<xsl:with-param name="start_idx" select="@idx"/>
		</xsl:call-template>
-->
		</xsl:for-each>
	</div>
</xsl:template>


<xsl:template match="JonchkiReport">
	<div id="toc">
		<!-- Show a table of contents. -->
		<h2><a name="toc">Table of Contents</a></h2>
		<b><big><a href="#system">System Information</a></big></b><br/>
		<b><big><a href="#project">Project Configuration</a></big></b><br/>
		<b><big><a href="#steps">Steps</a></big></b><br/>
	</div>
	
	<xsl:call-template name="system"/>
	<xsl:call-template name="project"/>
	<xsl:call-template name="artifacts"/>
</xsl:template>

</xsl:stylesheet>
