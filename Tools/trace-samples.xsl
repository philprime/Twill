<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text"/>
  <!-- Preserve IDs and references for single-pass aggregation, avoiding repeated
       document-wide lookups on recordings with many interned stacks. -->
  <xsl:template match="/">
    <xsl:for-each select="/trace-query-result/node/row">
      <!-- Separate result nodes prevent quadratic growth of one giant text node.
           Text output omits these wrapper elements. -->
      <sample>
        <xsl:if test="not(weight) or not(thread) or not(tagged-backtrace or sentinel)">
          <xsl:message terminate="yes">Missing time-profile weight, thread, or stack.</xsl:message>
        </xsl:if>
        <xsl:apply-templates select="weight"/>
        <xsl:apply-templates select="thread"/>
        <xsl:apply-templates select="tagged-backtrace"/>
        <xsl:apply-templates select="sentinel"/>
        <xsl:text>E&#10;</xsl:text>
      </sample>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="weight | thread | tagged-backtrace | frame | sentinel">
    <xsl:value-of select="name()"/><xsl:text>&#9;</xsl:text>
    <xsl:value-of select="@id"/><xsl:text>&#9;</xsl:text>
    <xsl:value-of select="@ref"/><xsl:text>&#9;</xsl:text>
    <xsl:choose>
      <xsl:when test="self::weight"><xsl:value-of select="."/></xsl:when>
      <xsl:when test="self::thread"><xsl:value-of select="translate(@fmt, '&#9;&#10;&#13;', '   ')"/></xsl:when>
      <xsl:when test="self::frame"><xsl:value-of select="translate(@name, '&#9;&#10;&#13;', '   ')"/></xsl:when>
    </xsl:choose>
    <xsl:text>&#10;</xsl:text>
    <xsl:apply-templates select="frame"/>
  </xsl:template>
</xsl:stylesheet>
