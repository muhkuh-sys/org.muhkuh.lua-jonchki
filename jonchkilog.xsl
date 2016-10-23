<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" indent="no" omit-xml-declaration="yes" encoding="UTF-8"/>

<xsl:template match="/">
	<html>
		<xsl:comment>XSLT stylesheet used to transform this file:  jonchkilog.xsl</xsl:comment>
		<head>
			<title>Jonchki Log</title>
		</head>
		<body bgcolor="#ffffff" marginheight="2" marginwidth="2" topmargin="2" leftmargin="2">
		<xsl:apply-templates select="JonchkiLog"/>
		</body>
	</html>
</xsl:template>


<xsl:template match="SystemConfiguration">
	<h2>System configuration</h2>
	<table border="1" cellspacing="0" cellpadding="2">
		<tr><td>work</td><td><xsl:value-of select="work"/></td></tr>
		<tr><td>cache</td><td><xsl:value-of select="cache"/></td></tr>
		<tr><td>cache_max_size</td><td><xsl:value-of select="cache/@max_size"/></td></tr>
		<tr><td>depack</td><td><xsl:value-of select="depack"/></td></tr>
		<tr><td>install_base</td><td><xsl:value-of select="install/base"/></td></tr>
		<tr><td>install_lua_path</td><td><xsl:value-of select="install/lua_path"/></td></tr>
		<tr><td>install_lua_cpath</td><td><xsl:value-of select="install/lua_cpath"/></td></tr>
		<tr><td>install_shared_objects</td><td><xsl:value-of select="install/shared_objects"/></td></tr>
		<tr><td>install_doc</td><td><xsl:value-of select="install/doc"/></td></tr>
	</table>
</xsl:template>

<xsl:template match="SystemConfig">
	<xsl:apply-templates select="SystemConfiguration"/>
</xsl:template>

<xsl:template match="System">
	<a name="system"/>
	<xsl:apply-templates select="SystemConfig"/>
</xsl:template>


<xsl:template match="repository">
	<tr><td colspan="3"><b><xsl:value-of select="@id"/></b></td></tr>
	<tr><td></td><td>type:</td><td><xsl:value-of select="@type"/></td></tr>
	<tr><td></td><td>cacheable:</td><td><xsl:value-of select="@cacheable"/></td></tr>
	<tr><td></td><td>root:</td><td><xsl:value-of select="root"/></td></tr>
	<tr><td></td><td>versions:</td><td><xsl:value-of select="versions"/></td></tr>
	<tr><td></td><td>config:</td><td><xsl:value-of select="config"/></td></tr>
	<tr><td></td><td>artifact:</td><td><xsl:value-of select="artifact"/></td></tr>
</xsl:template>

<xsl:template match="repositories">
	<h2>Repositories</h2>
	<table border="1" cellspacing="0" cellpadding="2">
		<xsl:apply-templates select="repository"/>
	</table>
</xsl:template>

<xsl:template match="jonchkicfg">
	<xsl:apply-templates select="repositories"/>
</xsl:template>


<xsl:template match="ProjectConfiguration">
	<a name="project"/>
	<h2>Project Configuration</h2>
	<xsl:apply-templates select="jonchkicfg"/>
</xsl:template>



<xsl:template match="Resolv">
	<table border="1" width="100%">
		<tr><td>Group-Artifact:</td><td><xsl:value-of select="concat(@group,'-',@artifact)"/></td></tr>
		<tr><td>Status:</td><td><xsl:value-of select="@status"/></td></tr>
	</table>
</xsl:template>

<xsl:template match="JonchkiResolvtab">
	<p>The resolve table</p>
	<xsl:apply-templates select="Resolv"/>
</xsl:template>

<xsl:template match="Step">
	<h3>Step <xsl:value-of select="@index"/></h3>
	<p><xsl:value-of select="Comment"/></p>

	<xsl:apply-templates select="JonchkiResolvtab"/>
</xsl:template>

<xsl:template match="Steps">
	<a name="steps"/>
	<h2>Steps</h2>
	Logged <xsl:value-of select="count(Step)"/> steps.
	<xsl:apply-templates select="Step"/>
</xsl:template>



<xsl:template match="JonchkiLog">
	<!-- Show a table of contents. -->
	<h2><a name="toc">Table of Contents</a></h2>
	<b><big><a href="#system">System Information</a></big></b><br/>
	<b><big><a href="#project">Project Configuration</a></big></b><br/>
	<b><big><a href="#steps">Steps</a></big></b><br/>

	<xsl:apply-templates select="System"/>
	<xsl:apply-templates select="ProjectConfiguration"/>
	<xsl:apply-templates select="Steps"/>
</xsl:template>

</xsl:stylesheet>
