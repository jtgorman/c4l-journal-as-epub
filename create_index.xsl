<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" />

  <!-- little odd, pulling out from the first record some of the
       metadata detail, as the issue info is in every "record" -->
  <xsl:template match="records">
   <html>
     <head>
       <title>Code4Lib Issue <xsl:value-of select="record[0]/issue" /></title>
     </head>
     <body>
       <xsl:apply-templates select="record[0]" mode="header" />

       <xsl:apply-templates select="record" />
     </body>
   </html>
  </xsl:template>

  <xsl:template match="record" mode="header">
    <h1>Code4Lib Issue <xsl:value-of select="issue" /> </h1>
    <span class="pubdate"><xsl:value-of select="publicationDate" /></span>
  </xsl:template>
  

  <xsl:template match="record">
    <div>
      <xsl:element name="a">
        <xsl:attribute name="href">
          <xsl:value-of select="concat(substring-after(fullTextUrl,'http://'),'/')" />
        </xsl:attribute>
        <span class="title"><xsl:value-of select="title" /></span>
      </xsl:element> <br />
      <xsl:apply-templates select="authors" />
      <xsl:apply-templates select="abstract" />
      
    </div>
  </xsl:template>

  <xsl:template match="author">
    <p class="author"><xsl:value-of select="." /></p>
  </xsl:template>

  <xsl:template match="abstract">
    <p class="abstract"><xsl:value-of select="." /></p>
  </xsl:template>
      

  
  <xsl:template match="*">
    <xsl:apply-templates select="*" />
  </xsl:template>
</xsl:stylesheet>
