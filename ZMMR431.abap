*&---------------------------------------------------------------------*
*& Report  ZMMR431
*&---------------------------------------------------------------------*
*& Projeto.....: 20200287.
*& Propósito...: Integração de Itens ao COUPA.
*& Solicitante.: Danilo Chamone Campos.
*& Autor.......: Marcos Antonio P. Amorim.
*&---------------------------------------------------------------------*
REPORT  zmmr431.

TABLES: mara, marc.
TYPE-POOLS sscr.
*&---------------------------------------------------------------------*
* INCLUDE
*&---------------------------------------------------------------------*
INCLUDE zmmr431_top.
INCLUDE zmmr431_zf1.

*...Bloco 2: Parâmetros de Seleção.
SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE text-b02.

SELECT-OPTIONS sc_mtart FOR mara-mtart.
SELECT-OPTIONS sc_werks FOR marc-werks OBLIGATORY.
*»-{bgn|ins|RCoimbra|2020.12|20200287}->
SELECT-OPTIONS s_matnr  FOR mara-matnr.
*<-{end|ins|RCoimbra|2020.12|20200287}-«
SELECTION-SCREEN SKIP.
PARAMETERS: p_dtfrom LIKE sy-datum DEFAULT sy-datum,
            p_utfrom LIKE sy-uzeit  DEFAULT sy-uzeit,
            p_numl TYPE zmme_coup_hour AS LISTBOX VISIBLE LENGTH 7  USER-COMMAND art DEFAULT 1.
****RIM-OAY-Inicio-28.06.2023-PRB0042138
SELECTION-SCREEN SKIP.
SELECT-OPTIONS s_tcode FOR syst-tcode NO INTERVALS . "Transacoes a desconsiderar
PARAMETERS p_called TYPE xfeld NO-DISPLAY DEFAULT space. "Chamada de outro programa
***RIM-OAY-Fim-28.06.2023-PRB0042138

SELECTION-SCREEN END OF BLOCK b02.

*&---------------------------------------------------------------------*
* INITIALIZATION
*&---------------------------------------------------------------------*
INITIALIZATION.
  PERFORM zf_busca_constantes.

*&---------------------------------------------------------------------*
* START-OF-SELECTION
*&---------------------------------------------------------------------*
START-OF-SELECTION.

** HYPERA - Inicio - WPMO - Ajuste ZMMR431(Materiais) - 12.11.2024 **
** Se o usuário inserir um material para envio, o sistema não      **
** ira acionar a regra de bloqueio de erro de envio.               **
  IF s_matnr IS INITIAL.
    vg_matnr = abap_false.
  ELSE.
    vg_matnr = abap_true.
  ENDIF.
** HYPERA - Fim - WPMO - Ajuste ZMMR431(Materiais) - 12.11.2024 **

*»-{bgn|ins|RCoimbra|2020.12|20200287}->
  PERFORM zf_lock_instance.
*<-{end|ins|RCoimbra|2020.12|20200287}-«
  IF vg_matnr IS INITIAL.
    zmmt_coupaexecdl-repid = sy-repid.
    zmmt_coupaexecdl-data = sy-datum.
    zmmt_coupaexecdl-hora = sy-uzeit.
  ENDIF.

  PERFORM zf_ranges.

  PERFORM zf_busca_dados.

  PERFORM zf_trata_dados.

  PERFORM zf_interface.

** HYPERA - WPO - Inicio - Ajustes ZMMR438 - 25.09.2024.
** Registrar Data e Hora do Termino do Job **
  IF vg_matnr IS INITIAL.
    zmmt_coupaexecdl-data_fim = sy-datum.
    zmmt_coupaexecdl-hora_fim = sy-uzeit.
    MODIFY zmmt_coupaexecdl.
  ENDIF.

** HYPERA - WPO - Fim - Ajustes ZMMR438 - 25.09.2024.


*&---------------------------------------------------------------------*
*&      Form  ZF_BUSCA_CONSTANTES
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM zf_busca_constantes .

  CONSTANTS: cl_nameprog TYPE ztge_constantes-programa  VALUE 'COUPA',
             cl_mtart    TYPE ztge_constantes-constante VALUE 'MTART',
             cl_bklas    TYPE ztge_constantes-constante VALUE 'BKLAS',
             cl_atinn    TYPE ztge_constantes-constante VALUE 'ATINN'.

  DATA: vl_valor TYPE ztge_constantes-valor,
        tl_valor TYPE TABLE OF string.

  FIELD-SYMBOLS: <fs_valor> TYPE string.

  SELECT SINGLE valor
    INTO vl_valor
    FROM ztge_constantes
    WHERE programa  = cl_nameprog
      AND constante = cl_mtart.
  IF sy-subrc EQ 0.
    REFRESH tl_valor.
    SPLIT vl_valor AT ';' INTO TABLE tl_valor.
    LOOP AT tl_valor ASSIGNING <fs_valor>.
      CLEAR wa_mtart.
      wa_mtart-sign   = 'I'.
      wa_mtart-option = 'EQ'.
      wa_mtart-low    = <fs_valor>.
      APPEND wa_mtart TO rg_mtart.
    ENDLOOP.
  ENDIF.

  SELECT SINGLE valor
    INTO vl_valor
    FROM ztge_constantes
    WHERE programa  = cl_nameprog
      AND constante = cl_atinn.
  IF sy-subrc EQ 0.
    REFRESH tl_valor.
    SPLIT vl_valor AT ';' INTO TABLE tl_valor.
    LOOP AT tl_valor ASSIGNING <fs_valor>.
      CLEAR wa_atinn.
      wa_atinn-sign   = 'I'.
      wa_atinn-option = 'EQ'.
      wa_atinn-low    = <fs_valor>.
      APPEND wa_atinn TO rg_atinn.
    ENDLOOP.
  ENDIF.

  SELECT SINGLE valor
    INTO vl_valor
    FROM ztge_constantes
    WHERE programa  = sy-repid
      AND constante = cl_bklas.
  IF sy-subrc IS INITIAL.
    REFRESH tl_valor.
    SPLIT vl_valor AT ';' INTO TABLE tl_valor.
    LOOP AT tl_valor ASSIGNING <fs_valor>.
      CLEAR wa_atinn.
      wa_bklas-sign   = 'I'.
      wa_bklas-option = 'EQ'.
      wa_bklas-low    = <fs_valor>.
      APPEND wa_bklas TO rg_bklas.
    ENDLOOP.
  ENDIF.

ENDFORM.                    " ZF_BUSCA_CONSTANTES
**&---------------------------------------------------------------------*
**&      Form  ZF_RANGES
**&---------------------------------------------------------------------*
**       text
**----------------------------------------------------------------------*
FORM zf_ranges .
  DATA:  vl_atinn           LIKE ausp-atinn.

** Tipo de objetoclas
  CLEAR wa_objectclas.
  wa_objectclas-sign   = 'I'.
  wa_objectclas-option = 'EQ'.
  wa_objectclas-low    = 'MATERIAL'.
  APPEND wa_objectclas TO rg_objectclas.

** Característica interna
  CALL FUNCTION 'CONVERSION_EXIT_ATINN_INPUT'
    EXPORTING
      input  = 'Z_MERCADORIA_NIVEL_1'
    IMPORTING
      output = vl_atinn.

  wa_atinn-sign   = 'I'.
  wa_atinn-option = 'EQ'.
  wa_atinn-low    = vl_atinn.
  APPEND wa_atinn TO rg_atinn.
  CLEAR: wa_atinn,vl_atinn.


** Característica interna
  CALL FUNCTION 'CONVERSION_EXIT_ATINN_INPUT'
    EXPORTING
      input  = 'Z_MERCADORIA_NIVEL_2'
    IMPORTING
      output = vl_atinn.

  wa_atinn-sign   = 'I'.
  wa_atinn-option = 'EQ'.
  wa_atinn-low    = vl_atinn.
  APPEND wa_atinn TO rg_atinn.
  CLEAR: wa_atinn,vl_atinn.


** Característica interna
  CALL FUNCTION 'CONVERSION_EXIT_ATINN_INPUT'
    EXPORTING
      input  = 'Z_MERCADORIA_NIVEL_3'
    IMPORTING
      output = vl_atinn.

  wa_atinn-sign   = 'I'.
  wa_atinn-option = 'EQ'.
  wa_atinn-low    = vl_atinn.
  APPEND wa_atinn TO rg_atinn.
  CLEAR: wa_atinn,vl_atinn.


** Característica interna
  CALL FUNCTION 'CONVERSION_EXIT_ATINN_INPUT'
    EXPORTING
      input  = 'Z_MERCADORIA_NIVEL_4'
    IMPORTING
      output = vl_atinn.


  wa_atinn-sign   = 'I'.
  wa_atinn-option = 'EQ'.
  wa_atinn-low    = vl_atinn.
  APPEND wa_atinn TO rg_atinn.
  CLEAR: wa_atinn,vl_atinn.

ENDFORM.                    " ZF_RANGES
*&---------------------------------------------------------------------*
*&      Form  ZF_BUSCA_DADOS
*&---------------------------------------------------------------------*
*  Buscar Dados Gerais                                                                    *
*----------------------------------------------------------------------*
FORM zf_busca_dados.

*»-{bgn|ins|RCoimbra|2020.12|20200287}->
  DATA: lt_matnr            TYPE STANDARD TABLE OF mara-matnr,
        lt_marc_ref         TYPE STANDARD TABLE OF marc,
        lt_zmmt_coupa_saida LIKE t_zmmt_coupa_saida[],
        lt_objek            TYPE STANDARD TABLE OF ausp-objek.

  DATA: ls_matnr    LIKE LINE OF lt_matnr[],
        ls_marc_ref LIKE LINE OF lt_marc_ref[],
        ls_objek    LIKE LINE OF lt_objek[].
*<-{end|ins|RCoimbra|2020.12|20200287}-«

  DATA:lv_hours(06)   TYPE n,
       lv_sum        TYPE i,
*  t_zmmt_coupa_aux TYPE STANDARD TABLE OF zmmt_coupa_logif,
        vl_date_of_change TYPE sy-datum,
        vl_time_of_change TYPE sy-uzeit.

***RIM - OAY - Inicio - 16.05.2023 - PRB0042074
  CONSTANTS: c_variante_00hs TYPE syslset VALUE '/MAT_COUPA_00H'.
***RIM - OAY - Fim - 16.05.2023 - PRB0042074


*** HYPERA - Inicio - WPO - Ajustes ZMMR438 - 28.08.2024.
  IF p_numl EQ '24'.
*********************************************************
*         Se  opção Carga Diaria                        *
*********************************************************
    vg_data = p_dtfrom - 1.
    vg_hora = p_utfrom.

  ELSEIF p_numl EQ '99'.
*********************************************************
*         Se  opção Ultima Carga                        *
*********************************************************
    SELECT data hora data_fim hora_fim
     INTO CORRESPONDING FIELDS OF TABLE gt_zmmt_coupaexecdl
     FROM zmmt_coupaexecdl
     WHERE repid EQ c_prog.
    IF sy-subrc EQ 0.
      SORT gt_zmmt_coupaexecdl BY hora DESCENDING.

      READ TABLE gt_zmmt_coupaexecdl INTO gs_zmmt_coupaexecdl INDEX 1.
      IF sy-subrc EQ 0.
* Verificar se os campos Data Fim e Hora fim estão preenchidos *
        IF gs_zmmt_coupaexecdl-data_fim IS INITIAL AND gs_zmmt_coupaexecdl-hora_fim IS INITIAL.
          vg_data  =  gs_zmmt_coupaexecdl-data.
          vg_hora  =  gs_zmmt_coupaexecdl-hora.
        ELSE. " Caso o contrario executar Job com a data da final da ultima execução.
          vg_data  =  gs_zmmt_coupaexecdl-data_fim.
          vg_hora  =  gs_zmmt_coupaexecdl-hora_fim.
        ENDIF.

      ENDIF.

    ELSE." Caso não encontre nada
      MESSAGE i784(zmm) DISPLAY LIKE 'E'.
      LEAVE LIST-PROCESSING.
    ENDIF.

  ELSE.
***************************************************************
* Se  opção Definir Horario                                   *
***************************************************************
    vg_data  = p_dtfrom.
    IF p_numl IS INITIAL.
      vg_hora  = p_utfrom.
    ELSE.
      lv_sum = p_numl.

      IF  p_numl = cg_30.

        lv_sum = cg_1.

        lv_hours =   ( lv_sum * 3600 ) / 2.

      ELSE.

        lv_hours =   ( lv_sum * 3600 ).

      ENDIF.
      vg_hora  =  p_utfrom - lv_hours.

    ENDIF.

  ENDIF.

  vl_time_of_change  =  vg_hora.
  vl_date_of_change  =  vg_data.

*** HYPERA - Fim - WPO - Ajustes ZMMR438 - 28.08.2024.

***RIM - OAY - Inicio - 28.06.2023 - PRB0042138
* Se a integração for individual
  IF NOT p_called IS INITIAL.
*   Seleciona dados de materiais
    SELECT   matnr
             lvorm
             mtart
             matkl
             meins
             bstme
             ekwsl
             mstae
             mfrnr
             bmatn
             mprof
        FROM mara                                       "#EC CI_NOORDER
        INTO TABLE t_mara
       WHERE matnr IN s_matnr AND
             mtart IN sc_mtart.

    IF sy-subrc EQ 0.
      SORT t_mara BY matnr.
*     Seleciona dados de controle de integracao
      SELECT matnr id_coupa
        FROM zmmt280                                    "#EC CI_NOORDER
        INTO CORRESPONDING FIELDS OF TABLE t_mmt280
         FOR ALL ENTRIES IN t_mara
       WHERE matnr = t_mara-matnr.

      IF sy-subrc IS INITIAL.
        SORT  t_mmt280  BY matnr.
      ENDIF.

*     Obtem dados de processamento de Dados Básicos materiais
      LOOP AT t_mara INTO wa_mara.

        READ TABLE t_mmt280 INTO wa_mmt280
                            WITH KEY matnr = wa_mara-matnr
                            BINARY SEARCH.

        IF sy-subrc IS INITIAL AND wa_mmt280-id_coupa IS NOT INITIAL.
          wa_zmmt_coupa_mara-matnr  =   wa_mmt280-matnr .   "2137008
          wa_zmmt_coupa_mara-id     =   wa_mmt280-id_coupa .
          IF wa_zmmt_coupa_mara-id IS INITIAL.
*           Envio de 	uma criação
            wa_zmmt_coupa_mara-tpmod  = 'I'.
          ELSE.
*           Envio de uma alteração
            wa_zmmt_coupa_mara-tpmod  = 'U'.
          ENDIF.
        ELSE.
          wa_zmmt_coupa_mara-matnr  = wa_mara-matnr.
*         Envio de uma criação
          wa_zmmt_coupa_mara-tpmod  = 'I'.
        ENDIF.
        wa_zmmt_coupa_mara-tpcad      = cg_1.
        wa_zmmt_coupa_mara-date       = sy-datum.
        wa_zmmt_coupa_mara-time       = sy-uzeit.

        APPEND wa_zmmt_coupa_mara TO t_zmmt_coupa_mara     .
        CLEAR wa_zmmt_coupa_mara.
      ENDLOOP.

*     Obtem dados de processamento de Dados de Centros
      SELECT matnr werks lvorm mmsta beskz steuc zz_herswerks
        INTO TABLE t_marc
        FROM marc
        FOR ALL ENTRIES IN t_mara
        WHERE matnr EQ t_mara-matnr
          AND werks IN sc_werks
          AND beskz NE 'E'.

      IF sy-subrc EQ 0.
*       Obtém dados de controle de integraçào de dados de Centros
        SELECT matnr id_coupa werks
          INTO CORRESPONDING FIELDS OF TABLE t_zmmt281
          FROM zmmt281
          FOR ALL ENTRIES IN t_marc
          WHERE matnr = t_marc-matnr
            AND werks = t_marc-werks.

        SORT t_zmmt281 BY matnr werks.

        LOOP AT t_marc INTO wa_marc.
          READ TABLE t_zmmt281 TRANSPORTING NO FIELDS
            WITH KEY matnr = wa_marc-matnr
                     werks = wa_marc-werks
                     BINARY SEARCH.
          IF sy-subrc IS NOT INITIAL.
            CLEAR wa_zmmt281.
            wa_zmmt281-matnr = wa_marc-matnr.
            wa_zmmt281-werks = wa_marc-werks.
            APPEND wa_zmmt281 TO t_zmmt281.
          ENDIF.
        ENDLOOP.

        SORT t_zmmt281 BY matnr werks.
        DELETE ADJACENT DUPLICATES FROM t_zmmt281
                              COMPARING matnr werks.

        LOOP AT t_zmmt281 INTO wa_zmmt281.
          CLEAR: vl_inser, vl_inser,
                 vl_current_number,
                 vl_current_numberx.

          wa_zmmt_coupa_marc-matnr    = wa_zmmt281-matnr.   "2137008.
          wa_zmmt_coupa_marc-id       = wa_zmmt281-id_coupa .
          wa_zmmt_coupa_marc-werks    = wa_zmmt281-werks.
          wa_zmmt_coupa_marc-tpcad    = cg_2.

          IF  wa_zmmt281-id_coupa IS INITIAL.
*           Envio de uma criação
            wa_zmmt_coupa_marc-tpmod  = 'I'.
          ELSE.
*           Envio de uma modificação
            wa_zmmt_coupa_marc-tpmod  = 'U'.
          ENDIF.

*         Gerar tabela de Log dados da modificação do centro
          APPEND wa_zmmt_coupa_marc TO t_zmmt_coupa_marc .
          CLEAR wa_zmmt_coupa_marc.
        ENDLOOP.
      ENDIF. "Select MARC
    ELSE.
      MESSAGE i784(zmm) DISPLAY LIKE 'E'.
      LEAVE LIST-PROCESSING.
    ENDIF. "Select MARA

  ELSE. "  Else do p_called.
***RIM - OAY - Fim - 28.06.2023 - PRB0042138


** HYPERA - Inicio - WPMO - Ajustes ZMMR431 - 08.10.2024.
***************************************
* Se for Selecionado Material na Tela *
***************************************
    IF NOT s_matnr IS INITIAL.

*   Seleciona dados de materiais
      SELECT   matnr
               lvorm
               mtart
               matkl
               meins
               bstme
               ekwsl
               mstae
               mfrnr
               bmatn
               mprof
          FROM mara                                     "#EC CI_NOORDER
          INTO TABLE t_mara
         WHERE matnr IN s_matnr AND
               mtart IN sc_mtart.

      IF sy-subrc EQ 0.
        SORT t_mara BY matnr.
*     Seleciona dados de controle de integracao
        SELECT matnr id_coupa
          FROM zmmt280                                  "#EC CI_NOORDER
          INTO CORRESPONDING FIELDS OF TABLE t_mmt280
           FOR ALL ENTRIES IN t_mara
         WHERE matnr = t_mara-matnr.

        IF sy-subrc IS INITIAL.
          SORT  t_mmt280  BY matnr.
        ENDIF.

*     Obtem dados de processamento de Dados Básicos materiais
        LOOP AT t_mara INTO wa_mara.

          READ TABLE t_mmt280 INTO wa_mmt280
                              WITH KEY matnr = wa_mara-matnr
                              BINARY SEARCH.

          IF sy-subrc IS INITIAL AND wa_mmt280-id_coupa IS NOT INITIAL.
            wa_zmmt_coupa_mara-matnr  =   wa_mmt280-matnr . "2137008
            wa_zmmt_coupa_mara-id     =   wa_mmt280-id_coupa .
            IF wa_zmmt_coupa_mara-id IS INITIAL.
*           Envio de 	uma criação
              wa_zmmt_coupa_mara-tpmod  = 'I'.
            ELSE.
*           Envio de uma alteração
              wa_zmmt_coupa_mara-tpmod  = 'U'.
            ENDIF.
          ELSE.
            wa_zmmt_coupa_mara-matnr  = wa_mara-matnr.
*         Envio de uma criação
            wa_zmmt_coupa_mara-tpmod  = 'I'.
          ENDIF.
          wa_zmmt_coupa_mara-tpcad      = cg_1.

          wa_zmmt_coupa_mara-date       = sy-datum.
          wa_zmmt_coupa_mara-time       = sy-uzeit.

          APPEND wa_zmmt_coupa_mara TO t_zmmt_coupa_mara     .
          CLEAR wa_zmmt_coupa_mara.
        ENDLOOP.

*     Obtem dados de processamento de Dados de Centros
        SELECT matnr werks lvorm mmsta beskz steuc zz_herswerks
          INTO TABLE t_marc
          FROM marc
          FOR ALL ENTRIES IN t_mara
          WHERE matnr EQ t_mara-matnr
            AND werks IN sc_werks
            AND beskz NE 'E'.

        IF sy-subrc EQ 0.
*       Obtém dados de controle de integraçào de dados de Centros
          SELECT matnr id_coupa werks
            INTO CORRESPONDING FIELDS OF TABLE t_zmmt281
            FROM zmmt281
            FOR ALL ENTRIES IN t_marc
            WHERE matnr = t_marc-matnr
              AND werks = t_marc-werks.

          SORT t_zmmt281 BY matnr werks.

          LOOP AT t_marc INTO wa_marc.
            READ TABLE t_zmmt281 TRANSPORTING NO FIELDS
              WITH KEY matnr = wa_marc-matnr
                       werks = wa_marc-werks
                       BINARY SEARCH.
            IF sy-subrc IS NOT INITIAL.
              CLEAR wa_zmmt281.
              wa_zmmt281-matnr = wa_marc-matnr.
              wa_zmmt281-werks = wa_marc-werks.
              APPEND wa_zmmt281 TO t_zmmt281.
            ENDIF.
          ENDLOOP.

          SORT t_zmmt281 BY matnr werks.
          DELETE ADJACENT DUPLICATES FROM t_zmmt281
                                COMPARING matnr werks.

          LOOP AT t_zmmt281 INTO wa_zmmt281.
            CLEAR: vl_inser, vl_inser,
                   vl_current_number,
                   vl_current_numberx.

            wa_zmmt_coupa_marc-matnr    = wa_zmmt281-matnr. "2137008.
            wa_zmmt_coupa_marc-id       = wa_zmmt281-id_coupa .
            wa_zmmt_coupa_marc-werks    = wa_zmmt281-werks.
            wa_zmmt_coupa_marc-tpcad    = cg_2.

            IF  wa_zmmt281-id_coupa IS INITIAL.
*           Envio de uma criação
              wa_zmmt_coupa_marc-tpmod  = 'I'.
            ELSE.
*           Envio de uma modificação
              wa_zmmt_coupa_marc-tpmod  = 'U'.
            ENDIF.

*         Gerar tabela de Log dados da modificação do centro
            APPEND wa_zmmt_coupa_marc TO t_zmmt_coupa_marc .
            CLEAR wa_zmmt_coupa_marc.
          ENDLOOP.
        ENDIF. "Select MARC
      ELSE.
        MESSAGE i784(zmm) DISPLAY LIKE 'E'.
        LEAVE LIST-PROCESSING.
      ENDIF. "Select MARA


    ELSE. " Else IF NOT S_MATNR IS INITIAL
** HYPERA - Inicio - WPMO - Ajustes ZMMR431 - 08.10.2024.

***************************************************************
*                Verifica Material Geral                      *
*=============================================================*
* Verifica se existe atualização a nível de dados  mestres do *
* Materiaís                                                   *

*=============================================================*
*»-{bgn|ins|RCoimbra|2020.12|20200287}->
    APPEND LINES OF s_matnr TO rg_objectid. "#EC CI_FLDEXT_OK[2215424]
*<-{end|ins|RCoimbra|2020.12|20200287}-«

******************************************************************
*  Busca os dados dos materiais modificados na data estabelecida *
******************************************************************
      SELECT  objectclas                                "#EC CI_NOORDER
              objectid
              changenr
              change_ind
              FROM cdhdr APPENDING TABLE t_cdhdr
           WHERE objectclas IN rg_objectclas   "MATERIAL
*»-{bgn|ins|RCoimbra|2020.12|20200287}->
           AND   objectid   IN rg_objectid
*<-{end|ins|RCoimbra|2020.12|20200287}-«
           AND   changenr   IN rg_changenr
           AND   username   IN rg_username
           AND   tcode      IN rg_tcode
           AND  (
                (    udate  =  vl_date_of_change
              AND    utime  >= vl_time_of_change
                 ) OR udate >  vl_date_of_change )
             AND (
                 ( udate  =  cg_date_until
              AND  utime <=  cg_time_until   )
              OR   udate <   cg_date_until   ).


*»-{bgn|ins|RCoimbra|2020.12|20200287}->
* delta por período
*--->S4 MIGRATION 02/01/2024 - MA
*    LOOP AT t_cdhdr INTO wa_cdhdr.
*      COLLECT wa_cdhdr-objectid(18) INTO lt_matnr.
*    ENDLOOP.
    LOOP AT t_cdhdr INTO wa_cdhdr.
      COLLECT wa_cdhdr-objectid(40) INTO lt_matnr.
    ENDLOOP.
*<---S4 MIGRATION 02/01/2024 - MA
* materiais com erro na última sincronização
      SELECT matnr
        APPENDING TABLE lt_matnr
        FROM zmmt280
        WHERE matnr IN s_matnr
          AND sync_date GE vg_data
          AND sync_time GE vg_hora
          AND sync_step_stat = '02'.

      SORT lt_matnr BY table_line.
      DELETE ADJACENT DUPLICATES FROM lt_matnr COMPARING table_line.
      IF lt_matnr[] IS NOT INITIAL.
*<-{end|ins|RCoimbra|2020.12|20200287}-«
*============================================================*
*   Verificar se Material modificado a nivel de Mestre       *
*   de Materiais foi enviado                                 *
*============================================================*
        SELECT   matnr
                 lvorm
                 mtart
                 matkl
                 meins
                 bstme
                 ekwsl
                 mstae
                 mfrnr
                 bmatn
                 mprof
                 FROM mara                              "#EC CI_NOORDER
                 INTO TABLE t_mara
*»-{bgn|mod|RCoimbra|2020.12|20200287}->
*             FOR ALL ENTRIES IN t_cdhdr
*             WHERE matnr = t_cdhdr-objectid(18)
                 FOR ALL ENTRIES IN lt_matnr
                 WHERE matnr = lt_matnr-table_line
*<-{end|mod|RCoimbra|2020.12|20200287}-«
                 AND  mtart  IN sc_mtart.

        IF sy-subrc IS INITIAL.
          SORT t_mara BY  matnr.

          SELECT  matnr id_coupa
                   FROM zmmt280                         "#EC CI_NOORDER
                   INTO CORRESPONDING FIELDS OF TABLE t_mmt280
                   FOR ALL ENTRIES IN t_mara
                   WHERE matnr = t_mara-matnr.
*»-{bgn|del|RCoimbra|2020.12|20200287}->
*               OR sync_step_stat = cg_2.
*<-{end|del|RCoimbra|2020.12|20200287}-«

          IF sy-subrc IS INITIAL.
            SORT  t_mmt280  BY matnr.
          ENDIF.
        ELSE.
          MESSAGE i784(zmm) DISPLAY LIKE 'E'.
          LEAVE LIST-PROCESSING.
        ENDIF.

*»-{bgn|mod|RCoimbra|2020.12|20200287}->
*    LOOP AT t_cdhdr INTO wa_cdhdr.
        LOOP AT lt_matnr INTO ls_matnr.
*<-{end|mod|RCoimbra|2020.12|20200287}-«

          READ TABLE t_mmt280 INTO wa_mmt280
*»-{bgn|mod|RCoimbra|2020.12|20200287}->
*                       WITH KEY matnr = wa_cdhdr-objectid(18)
                           WITH KEY matnr = ls_matnr
*<-{end|mod|RCoimbra|2020.12|20200287}-«
                                                   BINARY SEARCH.
          IF sy-subrc IS INITIAL
*»-{bgn|ins|RCoimbra|2020.12|20200287}->
          AND wa_mmt280-id_coupa IS NOT INITIAL.
*<-{end|ins|RCoimbra|2020.12|20200287}-«

*-----------------------------------------------------------*
*   Gerar  sequência numerica intervalo  de numeração       *
*-----------------------------------------------------------*
            wa_zmmt_coupa_mara-matnr  =   wa_mmt280-matnr . "2137008
            wa_zmmt_coupa_mara-id     =   wa_mmt280-id_coupa .

            IF wa_zmmt_coupa_mara-id IS INITIAL.
*         Envio de uma criação
              wa_zmmt_coupa_mara-tpmod  = 'I'.

            ELSE.
*         Envio de uma alteração
              wa_zmmt_coupa_mara-tpmod  = 'U'.
            ENDIF.
          ELSE.

*»-{bgn|ins|RCoimbra|2020.12|20200287}->
            wa_zmmt_coupa_mara-matnr  = ls_matnr.
*<-{end|ins|RCoimbra|2020.12|20200287}-«
*       Envio de uma criação
            wa_zmmt_coupa_mara-tpmod  = 'I'.
          ENDIF.
          wa_zmmt_coupa_mara-tpcad      = cg_1.

          wa_zmmt_coupa_mara-date       = sy-datum.
          wa_zmmt_coupa_mara-time       = sy-uzeit.

*     Gerar tabela de Log
          APPEND wa_zmmt_coupa_mara TO t_zmmt_coupa_mara     .
          CLEAR wa_zmmt_coupa_mara.
        ENDLOOP.
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*
*                      VERIFICA CENTRO                        *
*=============================================================*
*   Verifica se existe atualização a nível de Centro          *
*    no Material                                              *
*=============================================================*
*»-{bgn|ins|RCoimbra|2020.12|20200287}->
        IF t_cdhdr[] IS NOT INITIAL.
*<-{end|ins|RCoimbra|2020.12|20200287}-«

***   RIM - OAY - Inicio - 16.05.2023 - PRB0042074
*     Quando executado com a variante diferente das 00hs,
*     considerar somente as modificações de centros do material
*     na data e hora calculada no processamento.
          IF sy-slset NE c_variante_00hs.
***   RIM - OAY - Fim - 16.05.2023 - PRB0042074

            REFRESH t_cdpos.
            SELECT tabkey
              FROM cdpos APPENDING CORRESPONDING FIELDS OF TABLE t_cdpos "#EC CI_NOORDER
                         FOR ALL ENTRIES  IN t_cdhdr
                         WHERE  objectclas EQ t_cdhdr-objectclas
                         AND   objectid   EQ t_cdhdr-objectid
                         AND   changenr   EQ t_cdhdr-changenr
                         AND   tabname    IN ('MARC', 'MBEW').

***   RIM - OAY - Inicio - 16.05.2023 - PRB0042074
*     Se a execução está sendo feita com a variante das 00hs,
*     não considerar seleção por CHANGENR para considerar
*     todas as modificações de centros do material.
          ELSE.

            REFRESH t_cdpos.
            SELECT tabkey FROM cdpos
              APPENDING CORRESPONDING FIELDS OF TABLE t_cdpos "#EC CI_NOORDER
                         FOR ALL ENTRIES  IN t_cdhdr
                         WHERE  objectclas EQ t_cdhdr-objectclas
                         AND   objectid   EQ t_cdhdr-objectid
                         AND   tabname    IN ('MARC', 'MBEW').

          ENDIF.
***   RIM - OAY - Fim - 16.05.2023 - PRB0042074

*»-{bgn|ins|RCoimbra|2020.12|20200287}->
        ENDIF.
*<-{end|ins|RCoimbra|2020.12|20200287}-«


*»-{bgn|ins|RCoimbra|2020.12|20200287}->
*   delta por período
        LOOP AT t_cdpos INTO wa_cdpos.
          ls_marc_ref = wa_cdpos-tabkey.
          CHECK ls_marc_ref-werks IN sc_werks.
          COLLECT ls_marc_ref INTO lt_marc_ref.
        ENDLOOP.

*   materiais com erro na última sincronização
        SELECT matnr werks
          APPENDING CORRESPONDING FIELDS OF TABLE lt_marc_ref
          FROM zmmt281
          WHERE matnr IN s_matnr
            AND werks IN sc_werks
            AND sync_step_stat = '02'.

        SORT lt_marc_ref BY matnr werks.
        DELETE ADJACENT DUPLICATES FROM lt_marc_ref COMPARING matnr werks.
        IF lt_marc_ref[] IS NOT INITIAL.
*<-{end|ins|RCoimbra|2020.12|20200287}-«

*============================================================*
*   Verificar se Material modificado a nivel de Centro       *
*   foi enviado (tem o id coupa ou não)                      *
*============================================================*
*     Dados de centro para material
          SELECT matnr werks lvorm mmsta beskz steuc zz_herswerks
            INTO TABLE t_marc
            FROM marc
*»-{bgn|mod|RCoimbra|2020.12|20200287}->
*        FOR ALL ENTRIES IN t_cdpos
*        WHERE matnr =  t_cdpos-objectid(18)
*          AND werks  IN sc_werks
            FOR ALL ENTRIES IN lt_marc_ref
            WHERE matnr = lt_marc_ref-matnr
              AND werks = lt_marc_ref-werks
*<-{end|mod|RCoimbra|2020.12|20200287}-«
              AND beskz NE 'E'.

*»-{bgn|ins|RCoimbra|2020.12|20200287}->
          SELECT matnr id_coupa werks
            INTO CORRESPONDING FIELDS OF TABLE t_zmmt281
            FROM zmmt281
            FOR ALL ENTRIES IN lt_marc_ref
            WHERE matnr = lt_marc_ref-matnr
              AND werks = lt_marc_ref-werks.

          SORT t_zmmt281 BY matnr werks.
          LOOP AT t_marc INTO wa_marc.
            READ TABLE t_zmmt281 TRANSPORTING NO FIELDS
              WITH KEY matnr = wa_marc-matnr
                       werks = wa_marc-werks
                       BINARY SEARCH.
            IF sy-subrc IS NOT INITIAL.
              CLEAR wa_zmmt281.
              wa_zmmt281-matnr = wa_marc-matnr.
              wa_zmmt281-werks = wa_marc-werks.
              INSERT wa_zmmt281 INTO t_zmmt281 INDEX sy-tabix.
            ENDIF.
          ENDLOOP.
*<-{end|ins|RCoimbra|2020.12|20200287}-«

          SORT t_zmmt281 BY matnr werks.
          DELETE ADJACENT DUPLICATES FROM t_zmmt281 COMPARING matnr werks.

*     Em caso se sucesso
          LOOP AT t_zmmt281 INTO wa_zmmt281.
            CLEAR: vl_inser, vl_inser,
                   vl_current_number,
                   vl_current_numberx.

            vl_current_numberx          =    vl_current_number.
            wa_zmmt_coupa_marc-matnr    =    wa_zmmt281-matnr. "2137008.
            wa_zmmt_coupa_marc-id       =    wa_zmmt281-id_coupa .
            wa_zmmt_coupa_marc-werks    =    wa_zmmt281-werks.

            IF  wa_zmmt281-id_coupa IS INITIAL.
*         Envio de uma criação
              wa_zmmt_coupa_marc-tpmod  = 'I'.
            ELSE.
*         Envio de uma modificação
              wa_zmmt_coupa_marc-tpmod  = 'U'.
            ENDIF.
            wa_zmmt_coupa_marc-tpcad    = cg_2.

*       Gerar tabela de Log dados da modificação do centro
            APPEND wa_zmmt_coupa_marc  TO t_zmmt_coupa_marc .
            CLEAR wa_zmmt_coupa_marc.
            CLEAR wa_zmmt281.
          ENDLOOP.

        ENDIF.
      ENDIF."Check registro cdhdr

    ENDIF.

***RIM - OAY - Inicio - 28.06.2023 - PRB0042138
  ENDIF. "IF p_called
***RIM - OAY - Fim - 28.06.2023 - PRB0042138

  LOOP AT t_zmmt_coupa_mara INTO wa_zmmt_coupa_mara.
    APPEND wa_zmmt_coupa_mara TO t_zmmt_coupa_saida.
*»-{bgn|ins|RCoimbra|2020.12|20200287}->
    ls_objek = wa_zmmt_coupa_mara-matnr.
    COLLECT ls_objek INTO lt_objek.
*<-{end|ins|RCoimbra|2020.12|20200287}-«
  ENDLOOP.

  LOOP AT t_zmmt_coupa_marc INTO wa_zmmt_coupa_marc.
    APPEND wa_zmmt_coupa_marc TO t_zmmt_coupa_saida.
*»-{bgn|ins|RCoimbra|2020.12|20200287}->
    ls_objek = wa_zmmt_coupa_marc-matnr.
    COLLECT ls_objek INTO lt_objek.
*<-{end|ins|RCoimbra|2020.12|20200287}-«
  ENDLOOP.

  IF NOT t_zmmt_coupa_saida IS INITIAL.
*»-{bgn|ins|RCoimbra|2020.12|20200287}->
    lt_zmmt_coupa_saida[] = t_zmmt_coupa_saida[].
    SORT lt_zmmt_coupa_saida BY matnr.
    DELETE ADJACENT DUPLICATES FROM lt_zmmt_coupa_saida
                               COMPARING matnr.
*<-{end|ins|RCoimbra|2020.12|20200287}-«

    SORT  t_zmmt_coupa_saida BY matnr.
*   Textos breves de material
    SELECT matnr spras maktx
      INTO TABLE t_makt
      FROM makt
*»-{bgn|mod|RCoimbra|2020.12|20200287}->
*      FOR ALL ENTRIES IN t_zmmt_coupa_saida
*      WHERE matnr = t_zmmt_coupa_saida-matnr
      FOR ALL ENTRIES IN lt_zmmt_coupa_saida
      WHERE matnr = lt_zmmt_coupa_saida-matnr
*<-{end|mod|RCoimbra|2020.12|20200287}-«
     AND    ( spras = cg_pt OR spras = cg_en )  .

*   Item do documento de compras
    SELECT loekz matnr werks peinh netpr netwr bwtar pstyp
      INTO TABLE t_ekpo
      FROM ekpo
*»-{bgn|mod|RCoimbra|2020.12|20200287}->
*      FOR ALL ENTRIES IN t_zmmt_coupa_saida
*      WHERE matnr =  t_zmmt_coupa_saida-matnr.
      FOR ALL ENTRIES IN lt_zmmt_coupa_saida
      WHERE matnr =  lt_zmmt_coupa_saida-matnr
      AND   werks    IN sc_werks.
*<-{end|mod|RCoimbra|2020.12|20200287}-«

*   Dados gerais de material
    SELECT matnr lvorm mtart matkl meins bstme ekwsl mstae mfrnr bmatn mprof
      INTO TABLE t_mara
      FROM mara
*»-{bgn|mod|RCoimbra|2020.12|20200287}->
*      FOR ALL ENTRIES IN t_zmmt_coupa_saida
*      WHERE matnr =  t_zmmt_coupa_saida-matnr
      FOR ALL ENTRIES IN lt_zmmt_coupa_saida
      WHERE matnr = lt_zmmt_coupa_saida-matnr
*<-{end|mod|RCoimbra|2020.12|20200287}-«
*      AND mtart IN rg_mtart.
      AND mtart IN sc_mtart.

    REFRESH t_marc.
*   Dados de centro para material
    SELECT matnr werks lvorm mmsta beskz steuc zz_herswerks
      INTO TABLE t_marc
      FROM marc
*»-{bgn|mod|RCoimbra|2020.12|20200287}->
*      FOR ALL ENTRIES IN t_zmmt_coupa_saida
*      WHERE matnr =  t_zmmt_coupa_saida-matnr
      FOR ALL ENTRIES IN lt_zmmt_coupa_saida
      WHERE matnr = lt_zmmt_coupa_saida-matnr
*<-{end|mod|RCoimbra|2020.12|20200287}-«
        AND beskz NE 'E'.

*   Avaliação do material
    SELECT matnr  bwkey  bwtar
           verpr  peinh  bklas
      INTO TABLE t_mbew
      FROM mbew
*»-{bgn|mod|RCoimbra|2020.12|20200287}->
    FOR ALL ENTRIES IN t_zmmt_coupa_saida
      WHERE matnr   =  t_zmmt_coupa_saida-matnr
        AND bwkey   = t_zmmt_coupa_saida-werks
        AND bwtar   = space.
*      FOR ALL ENTRIES IN lt_zmmt_coupa_saida
*      WHERE matnr = lt_zmmt_coupa_saida-matnr
*<-{end|mod|RCoimbra|2020.12|20200287}-«

*   Valores das modalidades das características
    SELECT objek atinn klart atwrt
      INTO TABLE t_ausp
      FROM ausp
*»-{bgn|mod|RCoimbra|2020.12|20200287}->
*      WHERE objek IN rg_objk
      FOR ALL ENTRIES IN lt_objek
      WHERE objek EQ lt_objek-table_line
*<-{end|mod|RCoimbra|2020.12|20200287}-«
      AND atinn IN rg_atinn
      AND klart = '001'.
    IF sy-subrc IS INITIAL.
      SORT t_ausp BY objek  DESCENDING
                     atinn   DESCENDING .
      LOOP AT t_ausp INTO wa_ausp.
        MOVE-CORRESPONDING wa_ausp  TO wa_auspaux.
        AT NEW objek.
          wa_auspaux-atzhl = wa_auspaux-atwrt.
          APPEND wa_auspaux TO  t_auspaux.

        ENDAT.
        CLEAR wa_auspaux.
      ENDLOOP.
    ENDIF.

    IF NOT t_auspaux[] IS INITIAL.
*     Valores das modalidades das características
      SELECT  atinn atzhl atwtb
        INTO TABLE t_cawnt
        FROM cawnt
        FOR ALL ENTRIES IN t_auspaux
        WHERE atinn = t_auspaux-atinn
        AND   atzhl = t_auspaux-atzhl.
    ENDIF.
  ENDIF.


ENDFORM.                    " ZF_BUSCA_DADOS
*&---------------------------------------------------------------------*
*&      Form  ZF_TRATA_DADOS
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM zf_trata_dados .

  DATA: vl_name TYPE thead-tdname,
        lv_price TYPE ekpo-netwr.

  SORT: t_zmmt_coupa_mara BY matnr,
        t_makt  BY matnr spras,
        t_ekpo  BY matnr,
        t_mara  BY matnr,
        t_marc  BY matnr  werks,
        t_mbew  BY matnr  bwkey.

  LOOP AT  t_zmmt_coupa_saida INTO wa_zmmt_coupa_saida.

**** Inicio - DCN - 27/01/2022
**** Essa linha serve para preencher o item de material
**** por isso vai ler o primeiro centro que encontrar
    READ TABLE t_marc INTO wa_marc WITH KEY matnr = wa_zmmt_coupa_saida-matnr
                                            BINARY SEARCH.
    IF sy-subrc = 0.

      wa_saida-werks = wa_marc-werks.

      CONCATENATE  cg_txt wa_marc-werks   INTO wa_saida-contract_name .

      IF ( wa_marc-mmsta = '10' OR wa_marc-mmsta = space )
        AND wa_marc-lvorm = space.
        wa_saida-delete = abap_false.
      ELSE.
        wa_saida-delete = abap_true.
      ENDIF.
      wa_saida-ncm = wa_marc-steuc.

    ENDIF.



**** essa linha serve para preencher o item de centro
**** então vamos buscar os dados do centro especifico
    READ TABLE t_marc INTO wa_marc WITH KEY matnr = wa_zmmt_coupa_saida-matnr
                                            werks = wa_zmmt_coupa_saida-werks
                                            BINARY SEARCH.
    IF sy-subrc = 0.

      wa_saida-werks = wa_marc-werks.

      CONCATENATE  cg_txt wa_marc-werks   INTO wa_saida-contract_name .

      IF ( wa_marc-mmsta = '10' OR wa_marc-mmsta = space )
        AND wa_marc-lvorm = space.
        wa_saida-delete = abap_false.
      ELSE.
        wa_saida-delete = abap_true.
      ENDIF.
      wa_saida-ncm = wa_marc-steuc.

    ENDIF.
**** FIM - DCN - 27/01/2022


    READ TABLE t_makt INTO wa_makt
         WITH KEY matnr = wa_zmmt_coupa_saida-matnr
                 spras  = cg_pt
                  BINARY SEARCH.
    IF sy-subrc = 0.

      vl_name = wa_zmmt_coupa_saida-matnr .

*    Texto breve do material
      CALL FUNCTION 'READ_TEXT'
        EXPORTING
          client                  = sy-mandt
          id                      = 'BEST'
          language                = cg_pt
          name                    = vl_name
          object                  = 'MATERIAL'
        TABLES
          lines                   = t_tline
        EXCEPTIONS
          id                      = 1
          language                = 2
          name                    = 3
          not_found               = 4
          object                  = 5
          reference_check         = 6
          wrong_access_to_archive = 7
          OTHERS                  = 8.

      IF sy-subrc = 0 AND t_tline[] IS NOT INITIAL.
        LOOP AT t_tline INTO wa_tline.


          CONCATENATE wa_saida-texto_longo
                      wa_tline-tdline
                      INTO wa_saida-texto_longo  SEPARATED BY space.
          wa_saida-description = wa_saida-texto_longo.

        ENDLOOP.

      ENDIF.

    ENDIF.

    READ TABLE t_mara INTO wa_mara
         WITH KEY matnr = wa_zmmt_coupa_saida-matnr
                                   BINARY SEARCH.
    IF sy-subrc = 0.

      CONCATENATE wa_mara-matnr '-' wa_makt-maktx INTO wa_saida-name
                                                  SEPARATED BY space.

      IF  wa_saida-description IS INITIAL .
        wa_saida-description  = wa_makt-maktx.
      ENDIF.

      wa_saida-item_number   = wa_mara-matnr.
      wa_saida-item_type     = wa_mara-mtart.

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = wa_mara-meins
          language       = sy-langu
        IMPORTING
          output         = wa_saida-uom_code
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.


      wa_saida-mat_interno   = wa_mara-bmatn.
      wa_saida-manufact_name = wa_mara-mfrnr.

      IF ( wa_mara-mstae = '10'  OR wa_mara-mstae = space )
        AND wa_mara-lvorm = space.
        wa_saida-active = 'true'(001).
      ELSE.
        wa_saida-active = 'false'(002).
      ENDIF.

    ENDIF.

    READ TABLE t_mbew INTO wa_mbew
                      WITH KEY matnr = wa_zmmt_coupa_saida-matnr
                               bwkey = wa_zmmt_coupa_saida-werks
                      BINARY SEARCH.
    IF sy-subrc = 0.

      wa_saida-extern_refnum = wa_mbew-bwtar.
      lv_price = wa_mbew-verpr / wa_mbew-peinh.
      wa_saida-price = lv_price.
*      REPLACE ALL OCCURRENCES OF '.' IN wa_saida-price WITH space.
*      REPLACE ALL OCCURRENCES OF ',' IN wa_saida-price WITH '.'.
      CONDENSE wa_saida-price NO-GAPS.


      IF wa_mbew-bklas IN rg_bklas.
        wa_saida-bklas = wa_mbew-bklas.
      ENDIF.

    ENDIF.

    IF wa_saida-price IS INITIAL.
*     wa_saida-price = '00.01'.         "RIM-OAY-DEL-INC0106546
      wa_saida-price = cg_initial_price."RIM-OAY-ADD-INC0106546
    ENDIF.

    READ TABLE t_auspaux INTO wa_auspaux
         WITH KEY objek(18) = wa_zmmt_coupa_saida-matnr.

    IF sy-subrc = 0.

      READ TABLE t_cawnt INTO wa_cawnt
           WITH KEY atinn = wa_auspaux-atinn
                    atzhl = wa_auspaux-atzhl.
      wa_saida-comodity_name = wa_cawnt-atwtb.
    ENDIF.


    wa_saida-supplier_number = 99999999.

********rtm**************************************************************
******* Texto breve do materialEM INGLES
    READ TABLE t_makt INTO wa_makt
         WITH KEY matnr = wa_zmmt_coupa_saida-matnr
                 spras  = cg_en
                  BINARY SEARCH.
    IF sy-subrc EQ 0.
      wa_saida-texto_en = wa_makt-maktx.
    ENDIF.

******* Texto breve do materialEM INGLES
**********************************************************************

    APPEND wa_saida TO t_saida.
    CLEAR wa_saida.
  ENDLOOP.

***RIM - OAY - Inicio - INC0106546 - 31.05.2022
*  Ajuste para garantir que o registro do material com preço meior que 0.01 seja
*  considerado na integração do material.
*  SORT t_saida BY description item_number werks.
*
*  DELETE ADJACENT DUPLICATES FROM t_saida COMPARING description item_number werks.
  PERFORM f_reordena_saida CHANGING t_saida.
***RIM - OAY - Fim - INC0106546 - 31.05.2022

ENDFORM.                    " ZF_TRATA_DADOS
*&---------------------------------------------------------------------*
*&      Form  ZF_INTERFACE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM zf_interface .
  DATA: l_lines    TYPE i,
        l_linespos TYPE i,
        lv_data    TYPE datum, "DCN
        lv_hora    TYPE uzeit. "DCN
  CLEAR : wa_saida, wa_cdhdr.

*DCN - inicio
  lv_data = sy-datum.
  lv_hora = sy-uzeit.
*DCN - fim

  APPEND s_matnr TO rg_matnr.

  SORT t_cdhdr BY objectid.
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*
*                  GERAL                                              *
*=====================================================================*
*=====================================================================*
* Preparar Saida                                                      *
*=====================================================================*
  SORT t_zmmt_coupa_mara BY  matnr.
  SORT t_saida           BY  item_number.
  t_saida_aux = t_saida.
  DELETE ADJACENT DUPLICATES FROM t_zmmt_coupa_mara COMPARING matnr.
  DELETE ADJACENT DUPLICATES FROM t_saida COMPARING item_number.

  LOOP AT t_zmmt_coupa_mara INTO wa_zmmt_coupa_mara.

    READ TABLE t_saida INTO wa_saida
                       WITH KEY item_number = wa_zmmt_coupa_mara-matnr
                       BINARY SEARCH.
    IF NOT sy-subrc IS INITIAL.
      CONTINUE.
    ENDIF.

*=====================================================================*
*   Se for uma Criação                                                *
*=====================================================================*
    IF wa_zmmt_coupa_mara-tpmod = 'I'.

      CASE wa_zmmt_coupa_mara-tpcad .

        WHEN cg_1.
*=====================================================================*
*    Enviar inserção dos dados  Mestre de Material                    *
*=====================================================================*

          PERFORM zf_inserir_catalogitem CHANGING wa_saida lv_data lv_hora. "DCN

        WHEN cg_2.
*=====================================================================*
*    Enviar inserção dos dados a nível de Centro logistico            *
*=====================================================================*
          PERFORM zf_inserir_item CHANGING wa_saida lv_data lv_hora.

        WHEN OTHERS.

      ENDCASE.

*     Se for Uma Alteração
    ELSEIF wa_zmmt_coupa_mara-tpmod = 'U'.

      vl_id  = wa_zmmt_coupa_mara-id .

      CASE wa_zmmt_coupa_mara-tpcad .

        WHEN cg_1.
*=====================================================================*
*    Enviar atualização dos dados Mestre de Materiais                 *
*=====================================================================*
          PERFORM zf_atualizar_catalogitem USING wa_saida lv_data lv_hora. "DCN

        WHEN cg_2.

*=====================================================================*
*    Enviar atualização dos dados a nível de Centro logistico         *
*=====================================================================*
          PERFORM zf_atualizar_item USING wa_saida lv_data lv_hora. "DCN
      ENDCASE.
    ENDIF.
  ENDLOOP.

  REFRESH t_saida.
  t_saida = t_saida_aux.

*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*
*                      CENTRO LOGISTICO                               *
*=====================================================================*
*=====================================================================*
* Preparar Saida                                                      *
*=====================================================================*
  SORT t_saida BY item_number contract_name .
  LOOP AT t_zmmt_coupa_marc INTO wa_zmmt_coupa_marc.

    LOOP AT t_saida INTO wa_saida
                        WHERE item_number = wa_zmmt_coupa_marc-matnr
                        AND werks = wa_zmmt_coupa_marc-werks.

**=====================================================================*
**   Se for preciso deletar o item                                     *
**=====================================================================*
      IF wa_saida-delete EQ abap_true.
        PERFORM zf_delete_item USING wa_zmmt_coupa_marc.
        CONTINUE.
      ENDIF.

**=====================================================================*
**   Se for uma Criação                                                *
**=====================================================================*
      IF wa_zmmt_coupa_marc-tpmod = 'I'.

        CASE wa_zmmt_coupa_marc-tpcad .

          WHEN cg_1.
*=====================================================================*
*    Enviar inserção dos dados  Mestre de Material                    *
*=====================================================================*

            PERFORM zf_inserir_catalogitem USING wa_saida lv_data lv_hora. "DCN

          WHEN cg_2.

            SELECT matnr id_coupa werks FROM zmmt281    "#EC CI_NOORDER
                   INTO CORRESPONDING FIELDS OF TABLE t_zmmt281
                          WHERE matnr = wa_zmmt_coupa_marc-matnr
                          AND   werks = wa_zmmt_coupa_marc-werks.
            IF NOT sy-subrc IS INITIAL.

*=====================================================================*
*    Enviar inserção dos dados a nível de Centro logistico            *
*=====================================================================*
              PERFORM zf_inserir_item USING wa_saida lv_data lv_hora. "DCN

            ELSE.
              READ TABLE t_zmmt281 INTO wa_zmmt281 INDEX 1.

              IF wa_zmmt281-id_coupa = 0000.
*=====================================================================*
*    Enviar inserção dos dados a nível de Centro logistico            *
*=====================================================================*
                PERFORM zf_inserir_item USING wa_saida lv_data lv_hora. "DCN

              ENDIF.

            ENDIF.
*
*
*          WHEN OTHERS.
*
        ENDCASE.
*
*     Se for Uma Alteração
      ELSEIF wa_zmmt_coupa_marc-tpmod = 'U'.

        vl_id  = wa_zmmt_coupa_marc-id.

*      vl_id  = wa_zmmt281-id_coupa.

        CASE wa_zmmt_coupa_marc-tpcad .

          WHEN cg_1.
*=====================================================================*
*    Enviar atualização dos dados Mestre de Materiais                 *
*=====================================================================*
            PERFORM zf_atualizar_catalogitem USING wa_saida lv_data lv_hora. "DCN

          WHEN cg_2.
*=====================================================================*
*    Enviar atualização dos dados a nível de Centro logistico         *
*=====================================================================*
            PERFORM zf_atualizar_item USING wa_saida lv_data lv_hora. "DCN

        ENDCASE.

      ENDIF.
    ENDLOOP.
  ENDLOOP.

ENDFORM.                    " ZF_INTERFACE

*&---------------------------------------------------------------------*
*&      Form  F_REORDENA_SAIDA
*&---------------------------------------------------------------------*
*       Obtem tabela T_SAIDA ordenada por ITEM_NUMBER e WERKS
*       sem repeticao e com PRICE maior.
*       Rotina implementada porque SORT nao consegue order campo
*       PRICE de forma decrescente por ser campo STRING.
*&---------------------------------------------------------------------*
FORM f_reordena_saida  CHANGING pt_saida TYPE tyt_saida.

  DATA: lt_saida_chave TYPE TABLE OF ty_saida,
        st_saida_chave TYPE ty_saida,
        lt_saida_sem_valor TYPE TABLE OF ty_saida,
        st_saida_sem_valor TYPE ty_saida,
        lt_saida_com_valor TYPE TABLE OF ty_saida,
        st_saida_com_valor TYPE ty_saida,
        lt_saida_novo TYPE TABLE OF ty_saida.

* Elimina registros sem codigo de material
  DELETE pt_saida WHERE item_number IS INITIAL.

* Obtem tabela so com as chaves
  lt_saida_chave[] = pt_saida[].
  SORT lt_saida_chave BY item_number werks.
  DELETE ADJACENT DUPLICATES FROM lt_saida_chave
                             COMPARING item_number werks.

* Obtem tabela so com registros sem preco
  lt_saida_sem_valor[] = pt_saida[].
  SORT lt_saida_sem_valor BY price.
  DELETE lt_saida_sem_valor WHERE price NE cg_initial_price.
  SORT lt_saida_sem_valor BY item_number werks.

* Obtem tabela so com registros com preco
  lt_saida_com_valor[] = pt_saida[].
  SORT lt_saida_com_valor BY price.
  DELETE lt_saida_com_valor WHERE price EQ cg_initial_price.
  SORT lt_saida_com_valor BY item_number werks.

* Monta nova tabela de saida com registros com preco caso existir e
* caso nao encontre, considera o registro sem preco.
  LOOP AT lt_saida_chave INTO st_saida_chave.

    READ TABLE lt_saida_com_valor INTO st_saida_com_valor
                                  WITH KEY item_number = st_saida_chave-item_number
                                           werks       = st_saida_chave-werks
                                           BINARY SEARCH.
    IF sy-subrc EQ 0.
      APPEND st_saida_com_valor TO lt_saida_novo.
    ELSE.
      READ TABLE lt_saida_sem_valor INTO st_saida_sem_valor
                                      WITH KEY item_number = st_saida_chave-item_number
                                               werks       = st_saida_chave-werks
                                               BINARY SEARCH.
      IF sy-subrc EQ 0.
        APPEND st_saida_sem_valor TO lt_saida_novo.
      ENDIF.
    ENDIF.

  ENDLOOP.

  IF NOT lt_saida_novo[] IS INITIAL.
    pt_saida[] = lt_saida_novo[].
  ENDIF.

ENDFORM.                    " F_REORDENA_SAIDA

*&---------------------------------------------------------------------*
*&      Form  ZF_PARAMETRIZAR_SELECT_OPTION
*&---------------------------------------------------------------------*
FORM zf_parametrizar_select_option .

  DATA: st_optlist  TYPE sscr_opt_list,
        st_restrict TYPE sscr_restrict,
        st_ass      TYPE sscr_ass.


  st_optlist-name = 'TCODE'.
  st_optlist-options-eq = 'X'.
  APPEND st_optlist TO st_restrict-opt_list_tab.

  st_ass-kind = 'S'.
  st_ass-name = 'S_TCODE'.
  st_ass-sg_main = 'I'.
  st_ass-op_main = 'TCODE'.
  APPEND st_ass TO st_restrict-ass_tab.

  CALL FUNCTION 'SELECT_OPTIONS_RESTRICT'
    EXPORTING
*     PROGRAM                      =
      restriction                  = st_restrict
*     DB                           = ' '
   EXCEPTIONS
     too_late                     = 1
     repeated                     = 2
     selopt_without_options       = 3
     selopt_without_signs         = 4
     invalid_sign                 = 5
     empty_option_list            = 6
     invalid_kind                 = 7
     repeated_kind_a              = 8
     OTHERS                       = 9
            .
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.


ENDFORM.                    " ZF_PARAMETRIZAR_SELECT_OPTION