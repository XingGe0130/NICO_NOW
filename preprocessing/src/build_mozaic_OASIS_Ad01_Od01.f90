program modif                                         
               
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! N. Jourdain, CCRC-UNSW, April 2014
!
! Updates: - Oct. 2014: take LAKEMASK into account 
!                       (for WRFv3.6, but still works with earlier releases)
!
! Used to create remapping files to specify exchange addresses and
! interpolation weights in OASIS.
!
! NB: you need to create cplmask.nc before (contains corrected LANDMASK)
!
! Choose : perio=1 if you use East-West boundary conditions, 
!          perio=0 in other cases
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                       
USE netcdf                                           

IMPLICIT NONE                                         
                                                      
!----- namelist parameters -----
namelist /parent/ conf_par, perio, max_dom, feedback, idateline, file_par_coord, file_eff_land
namelist /child/ conf_child, file_child_coord, file_child_extend
INTEGER                                  :: max_dom, feedback, perio, idateline
CHARACTER(LEN=150)                       :: file_par_coord, file_eff_land, file_child_coord, file_child_extend
CHARACTER(LEN=50)                        :: conf_par, conf_child

!-----------

INTEGER                                  :: i, j, k, status, dimID_dst_grid_size, dimID_src_grid_size, dimID_num_wgts, dimID_num_links, mdst_grid_size_a2o, &
&                                           msrc_grid_size_a2o, mdst_grid_size_o2a, msrc_grid_size_o2a, mnum_wgts, mnum_links_a2o, mnum_links_o2a,          &
&                                           remap_matrix_ID, dst_address_ID, src_address_ID, fida2o, fido2a, counter_atm, counter_oce,                      &
&                                           iWRF, jWRF, iNEMO, jNEMO, fidWG
INTEGER*8,ALLOCATABLE,DIMENSION(:)       :: dst_address_a2o, src_address_a2o, dst_address_o2a, src_address_o2a
CHARACTER(LEN=150)                       :: file_out_a2o, file_out_o2a 
REAL*8,ALLOCATABLE,DIMENSION(:,:)        :: remap_matrix_a2o, remap_matrix_o2a 
INTEGER                                  :: fidOce, dimID_x, dimID_y, dimID_z, dimID_t, mx, my, mz, mt, tmask_ID, umask_ID, vmask_ID, &
&                                           glamt_ID, glamu_ID, glamv_ID, gphit_ID, gphiu_ID, gphiv_ID, ilake
CHARACTER(LEN=150)                       :: file_in_Oce                     
INTEGER*1,ALLOCATABLE,DIMENSION(:,:,:,:) :: tmask 
INTEGER                                  :: fidAtm, dimID_month, dimID_soil_cat, dimID_land_cat, dimID_west_east_stag, dimID_south_north_stag, &
&                                           dimID_south_north, dimID_west_east, dimID_DateStrLen, dimID_Time, mmonth, msoil_cat, mland_cat,    &
&                                           mwest_east_stag, msouth_north_stag, msouth_north, mwest_east, mDateStrLen, mTime, LANDMASK_ID,     &
&                                           XLONG_U_ID, XLAT_U_ID, XLONG_V_ID, XLAT_V_ID, XLONG_M_ID, XLAT_M_ID, LAKEMASK_ID
CHARACTER(LEN=150)                       :: file_in_Atm  
REAL*4,ALLOCATABLE,DIMENSION(:,:,:)      :: LANDMASK, LAKEMASK
INTEGER*8, ALLOCATABLE, DIMENSION(:,:)   :: adress_atm, adress_oce
                                                      
!=================================================================================
! 0- Initializations 
!=================================================================================

!- read namelist values
OPEN (UNIT=1, FILE='namelist_precpl' )
READ (UNIT=1, NML=parent)
if ( max_dom .gt. 1 ) READ (UNIT=1, NML=child)
CLOSE(1)

write(file_in_Oce,110) TRIM(conf_par)
110 FORMAT('mesh_mask_',a,'.nc')

file_in_Atm = file_par_coord

if ( max_dom .gt. 1 ) then
  write(file_out_a2o,111) TRIM(conf_par), TRIM(conf_child)
  111 FORMAT('mozaic_Ad01_to_Od01_',a,'_',a,'.nc')
  write(file_out_o2a,112) TRIM(conf_par), TRIM(conf_child)
  112 FORMAT('mozaic_Od01_to_Ad01_',a,'_',a,'.nc')
else
  write(file_out_a2o,113) TRIM(conf_par)
  113 FORMAT('mozaic_Ad01_to_Od01_',a,'.nc')
  write(file_out_o2a,114) TRIM(conf_par)
  114 FORMAT('mozaic_Od01_to_Ad01_',a,'.nc')
endif

  write(*,*) '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
  write(*,*) ' build_mozaic_OASIS_Ad01_Od01  :                     '
  write(*,*) ' ~~~~~~~~~~~~~~~~~~~~~~~~~~~~                        '
  write(*,*) '                                                     '
  write(*,*) '   parent config : ', TRIM(conf_par)
if ( max_dom .gt. 1 ) then
  write(*,*) '   child  config : ', TRIM(conf_child)
endif
  write(*,*) '                                                     '
  write(*,*) '               - max_dom  = ', max_dom
  write(*,*) '               - perio    = ', perio
  write(*,*) '                                                     '
                                                           
!=================================================================================
! 1- Read Ocean mask
!=================================================================================

         write(*,*) ' '
         write(*,*) ' Reading ', TRIM(file_in_Oce)
                                                           
         status = NF90_OPEN(TRIM(file_in_Oce),0,fidOce)          
         call erreur(status,.TRUE.,"read") 
                                                           
       !Lecture des ID des dimensions qui nous interessent
         status = NF90_INQ_DIMID(fidOce,"x",dimID_x)
         call erreur(status,.TRUE.,"inq_dimID_x")
         status = NF90_INQ_DIMID(fidOce,"y",dimID_y)
         call erreur(status,.TRUE.,"inq_dimID_y")
         status = NF90_INQ_DIMID(fidOce,"z",dimID_z)
         call erreur(status,.TRUE.,"inq_dimID_z")
         status = NF90_INQ_DIMID(fidOce,"t",dimID_t)
         call erreur(status,.TRUE.,"inq_dimID_t")
                                                               
       !Lecture des valeurs des dimensions qui nous interessent
         status = NF90_INQUIRE_DIMENSION(fidOce,dimID_x,len=mx)
         call erreur(status,.TRUE.,"inq_dim_x")
         status = NF90_INQUIRE_DIMENSION(fidOce,dimID_y,len=my)
         call erreur(status,.TRUE.,"inq_dim_y")
         status = NF90_INQUIRE_DIMENSION(fidOce,dimID_z,len=mz)
         call erreur(status,.TRUE.,"inq_dim_z")
         status = NF90_INQUIRE_DIMENSION(fidOce,dimID_t,len=mt)
         call erreur(status,.TRUE.,"inq_dim_t")
                               
       !Allocation of arrays : 
         ALLOCATE(  tmask(mx,my,mz,mt) ) 
         ALLOCATE(  adress_oce(mx,my)  )         
                        
       !Lecture des ID des variables qui nous interessent
         status = NF90_INQ_VARID(fidOce,"tmask",tmask_ID)
         call erreur(status,.TRUE.,"inq_tmask_ID")
                                                              
       !Lecture des valeurs des variables qui nous interessent
         status = NF90_GET_VAR(fidOce,tmask_ID,tmask)
         call erreur(status,.TRUE.,"getvar_tmask")
                                                      
     !Fermeture du fichier lu                         
       status = NF90_CLOSE(fidOce)                      
       call erreur(status,.TRUE.,"fin_lecture")     
                                                 
!=================================================================================
! 2- Read Atmospheric mask
!=================================================================================     
        
         write(*,*) ' '
         write(*,*) ' Reading ', TRIM(file_in_Atm)
                                                  
         status = NF90_OPEN(TRIM(file_in_Atm),0,fidAtm)          
         call erreur(status,.TRUE.,"read") 
                                                           
       !Lecture des ID des dimensions qui nous interessent
         status = NF90_INQ_DIMID(fidAtm,"south_north",dimID_south_north)
         call erreur(status,.TRUE.,"inq_dimID_south_north")
         status = NF90_INQ_DIMID(fidAtm,"west_east",dimID_west_east)
         call erreur(status,.TRUE.,"inq_dimID_west_east")
                                                               
       !Lecture des valeurs des dimensions qui nous interessent
         status = NF90_INQUIRE_DIMENSION(fidAtm,dimID_south_north,len=msouth_north)
         call erreur(status,.TRUE.,"inq_dim_south_north")
         status = NF90_INQUIRE_DIMENSION(fidAtm,dimID_west_east,len=mwest_east)
         call erreur(status,.TRUE.,"inq_dim_west_east")
                               
       !Allocation of arrays : 
         ALLOCATE(  LANDMASK  (mwest_east  ,msouth_north  ,1)  ) 
         ALLOCATE(  LAKEMASK  (mwest_east  ,msouth_north  ,1)  )
         ALLOCATE(  adress_atm(mwest_east+1,msouth_north+1  )  )         
                        
       !Lecture des ID des variables qui nous interessent
         status = NF90_INQ_VARID(fidAtm,"LANDMASK",LANDMASK_ID)
         call erreur(status,.TRUE.,"inq_LANDMASK_ID")
         ilake = NF90_INQ_VARID(fidAtm,"LAKEMASK",LAKEMASK_ID)
         write(*,*) ' '
         if ( ilake .ne. 0 ) then
           write(*,*) '  WARNING: no LAKEMASK variable in wrfinput_d01 ===> assuming no lake'
         else
           write(*,*) '  Using LAKEMASK information'
         endif
         write(*,*) ' '
                                                              
       !Lecture des valeurs des variables qui nous interessent
         status = NF90_GET_VAR(fidAtm,LANDMASK_ID,LANDMASK)
         call erreur(status,.TRUE.,"getvar_LANDMASK")
         if ( ilake .eq. 0 ) then
           status = NF90_GET_VAR(fidAtm,LAKEMASK_ID,LAKEMASK)
           call erreur(status,.TRUE.,"getvar_LAKEMASK")
         else
           LAKEMASK(:,:,:) = 0.0
         endif         
                                             
     !Fermeture du fichier lu                         
       status = NF90_CLOSE(fidAtm)                      
       call erreur(status,.TRUE.,"fin_lecture")     

!--------------------------------------------
!- if updated landmask due to 2-way nesting :
if ( max_dom .gt. 1 .and. feedback .eq. 1 ) then

   write(*,*) '  '
   write(*,*) '   2-way nesting -> must consider effective landmask for coupling'
   write(*,*) '                 -> ', TRIM(file_eff_land)

   status = NF90_OPEN(TRIM(file_eff_land),0,fidWG)
   call erreur(status,.TRUE.,"Read file eff_landmask")

   status = NF90_INQ_VARID(fidWG,"LANDMASK",LANDMASK_ID)
   call erreur(status,.TRUE.,"Inquire LANDMASK ID")

   status = NF90_GET_VAR(fidWG,LANDMASK_ID,LANDMASK)
   call erreur(status,.TRUE.,"Get variable LANDMASK")

   status = NF90_CLOSE(fidWG)
   call erreur(status,.TRUE.,"close netcdf file")

endif
 
!=================================================================================
! 3- Calculation of mozaic parameters
!=================================================================================

!=======================
! 0- Define adresses

write(*,*) ' '
write(*,*) 'Define adresses'

counter_atm = 0
do j=1,msouth_north+1 !- to include stagged variables
do i=1,mwest_east+1 !- to include stagged variables
  counter_atm = counter_atm + 1
  adress_atm(i,j)=counter_atm
enddo
enddo

counter_oce = 0
do j=1,my
do i=1,mx
  counter_oce = counter_oce + 1
  adress_oce(i,j)=counter_oce
enddo
enddo

!=======================================
! A- Atmosphere to Ocean (d01 to d01) :

write(*,*) 'Atmosphere to Ocean (d01 to d01) :'

msrc_grid_size_a2o = (mwest_east+1) * (msouth_north+1)
mdst_grid_size_a2o = mx * my                        

write(*,*) msrc_grid_size_a2o, mdst_grid_size_a2o

if ( perio .eq. 1 ) then  !- East-West periodic grid
  mnum_links_a2o = NINT( SUM( SUM( FLOAT(tmask(:,2:my-1,1,1)) , 2 ) , 1 ) )
else
  mnum_links_a2o = NINT( SUM( SUM( FLOAT(tmask(2:mx-1,2:my-1,1,1)) , 2 ) , 1 ) )
endif
ALLOCATE( src_address_a2o(mnum_links_a2o) )
ALLOCATE( dst_address_a2o(mnum_links_a2o) )
ALLOCATE( remap_matrix_a2o(1,mnum_links_a2o) )

write(*,*) '   -> ', mnum_links_a2o, ' links'

mnum_links_a2o = 0
if ( perio .eq. 1 ) then  !- East-West periodic grid
  do j=2,my-1
  do i=1,mx
    if ( tmask(i,j,1,1) .eq. 1 ) then
      mnum_links_a2o=mnum_links_a2o+1
      iWRF=i-1
      if ( i .eq. mx ) iWRF=1
      if ( i .eq.  1 ) iWRF=mx-2
      jWRF=j 
      src_address_a2o(mnum_links_a2o) = adress_atm(iWRF,jWRF)
      dst_address_a2o(mnum_links_a2o) = adress_oce(i,j)
    endif
  enddo
  enddo
else ! no grid periodicity
  do j=2,my-1
  do i=2,mx-1
    if ( tmask(i,j,1,1) .eq. 1 ) then
      mnum_links_a2o=mnum_links_a2o+1
      iWRF=i
      jWRF=j
      src_address_a2o(mnum_links_a2o) = adress_atm(iWRF,jWRF)
      dst_address_a2o(mnum_links_a2o) = adress_oce(i,j)
    endif
  enddo
  enddo
endif

remap_matrix_a2o(:,:) = 1.0

!=======================================
! B- Ocean to Atmosphere (d01 to d01) :

write(*,*) 'Ocean to Atmosphere (d01 to d01) :'

msrc_grid_size_o2a = mx * my
mdst_grid_size_o2a = (mwest_east+1) * (msouth_north+1) ! must be able to transfer stagged fields

write(*,*) msrc_grid_size_o2a, mdst_grid_size_o2a

mnum_links_o2a = NINT( SUM( SUM( ( 1-LANDMASK(:,:,1)-LAKEMASK(:,:,1) ), 2 ), 1 ) )

ALLOCATE( remap_matrix_o2a(1,mnum_links_o2a) )
ALLOCATE( dst_address_o2a(mnum_links_o2a) )
ALLOCATE( src_address_o2a(mnum_links_o2a) )

write(*,*) '   -> ', mnum_links_o2a, ' links'

!- The three first lines of WRF are filled with NEMO's third line:
!  then, NEMO's 4th line fills WRF's 4th line, etc...
!  until my-1

mnum_links_o2a = 0
if ( perio .eq. 1 ) then ! East-West periodicity
  do j=1,msouth_north ! we do not need to bring ocean fields to the stagged row
  do i=1,mwest_east   ! we do not need to bring ocean fields to the stagged column
    if ( LANDMASK(i,j,1)+LAKEMASK(i,j,1) .lt. 0.5 ) then
      mnum_links_o2a = mnum_links_o2a + 1
      iNEMO=i+1
      if ( i .eq. mwest_east ) iNEMO=2
      jNEMO=MIN(MAX(j,3),my-2)
      src_address_o2a(mnum_links_o2a) = adress_oce(iNEMO,jNEMO)
      dst_address_o2a(mnum_links_o2a) = adress_atm(i,j)
    endif
  enddo
  enddo
else ! no periodicity
  do j=1,msouth_north ! we do not need to bring ocean fields to the stagged row
  do i=1,mwest_east   ! we do not need to bring ocean fields to the stagged column
    if ( LANDMASK(i,j,1)+LAKEMASK(i,j,1) .lt. 0.5 ) then
      mnum_links_o2a = mnum_links_o2a + 1
      iNEMO=MIN(MAX(i,3),mx-2)
      jNEMO=MIN(MAX(j,3),my-2)
      src_address_o2a(mnum_links_o2a) = adress_oce(iNEMO,jNEMO)
      dst_address_o2a(mnum_links_o2a) = adress_atm(i,j)
    endif
  enddo
  enddo
endif

remap_matrix_o2a(:,:) = 1.0
                      
!=================================================================================
! 4a- Writing file_out_a2o
!=================================================================================     
             
        write(*,*) ' '
        write(*,*) 'Writing ', TRIM(file_out_a2o)
                                            
        status = NF90_CREATE(TRIM(file_out_a2o),or(NF90_NOCLOBBER,NF90_64BIT_OFFSET),fida2o)
        call erreur(status,.TRUE.,'create')                     
                                                                
        !Definition des dimensions du fichiers                  
         status = NF90_DEF_DIM(fida2o,"dst_grid_size",mdst_grid_size_a2o,dimID_dst_grid_size)
         call erreur(status,.TRUE.,"def_dimID_dst_grid_size")
         status = NF90_DEF_DIM(fida2o,"src_grid_size",msrc_grid_size_a2o,dimID_src_grid_size)
         call erreur(status,.TRUE.,"def_dimID_src_grid_size")
         status = NF90_DEF_DIM(fida2o,"num_wgts",1,dimID_num_wgts)
         call erreur(status,.TRUE.,"def_dimID_num_wgts")
         status = NF90_DEF_DIM(fida2o,"num_links",mnum_links_a2o,dimID_num_links)
         call erreur(status,.TRUE.,"def_dimID_num_links")
                                                              
        !Definition des variables                             
         status = NF90_DEF_VAR(fida2o,"remap_matrix",NF90_DOUBLE,(/dimID_num_wgts,dimID_num_links/),remap_matrix_ID)
         call erreur(status,.TRUE.,"def_var_remap_matrix_ID")
         status = NF90_DEF_VAR(fida2o,"dst_address",NF90_INT,(/dimID_num_links/),dst_address_ID)
         call erreur(status,.TRUE.,"def_var_dst_address_ID")
         status = NF90_DEF_VAR(fida2o,"src_address",NF90_INT,(/dimID_num_links/),src_address_ID)
         call erreur(status,.TRUE.,"def_var_src_address_ID")
                                   
        ! Attributs globaux       :
         status = NF90_PUT_ATT(fida2o,NF90_GLOBAL,"history","created using build_mozaic_OASIS_Ad01_Od01.f90")
         call erreur(status,.TRUE.,"put_att_GLOBAL_ID")
                                                      
        !Fin des definitions                          
         status = NF90_ENDDEF(fida2o)                   
         call erreur(status,.TRUE.,"fin_definition") 
                                                      
        !Valeurs prises par les variables :           
         status = NF90_PUT_VAR(fida2o,remap_matrix_ID,remap_matrix_a2o)
         call erreur(status,.TRUE.,"var_remap_matrix_ID")
         status = NF90_PUT_VAR(fida2o,dst_address_ID,dst_address_a2o)
         call erreur(status,.TRUE.,"var_dst_address_ID")
         status = NF90_PUT_VAR(fida2o,src_address_ID,src_address_a2o)
         call erreur(status,.TRUE.,"var_src_address_ID")
                                                      
        !Fin de l'ecriture                            
         status = NF90_CLOSE(fida2o)                    
         call erreur(status,.TRUE.,"final")         

!=================================================================================
! 4b- Writing file_out_o2a
!=================================================================================      
   
        write(*,*) ' '
        write(*,*) 'Writing ', TRIM(file_out_o2a)
                                                     
        status = NF90_CREATE(TRIM(file_out_o2a),or(NF90_NOCLOBBER,NF90_64BIT_OFFSET),fido2a)
        call erreur(status,.TRUE.,'create')                     
                                                                
        !Definition des dimensions du fichiers                  
         status = NF90_DEF_DIM(fido2a,"dst_grid_size",mdst_grid_size_o2a,dimID_dst_grid_size)
         call erreur(status,.TRUE.,"def_dimID_dst_grid_size")
         status = NF90_DEF_DIM(fido2a,"src_grid_size",msrc_grid_size_o2a,dimID_src_grid_size)
         call erreur(status,.TRUE.,"def_dimID_src_grid_size")
         status = NF90_DEF_DIM(fido2a,"num_wgts",1,dimID_num_wgts)
         call erreur(status,.TRUE.,"def_dimID_num_wgts")
         status = NF90_DEF_DIM(fido2a,"num_links",mnum_links_o2a,dimID_num_links)
         call erreur(status,.TRUE.,"def_dimID_num_links")
                                                              
        !Definition des variables                             
         status = NF90_DEF_VAR(fido2a,"remap_matrix",NF90_DOUBLE,(/dimID_num_wgts,dimID_num_links/),remap_matrix_ID)
         call erreur(status,.TRUE.,"def_var_remap_matrix_ID")
         status = NF90_DEF_VAR(fido2a,"dst_address",NF90_INT,(/dimID_num_links/),dst_address_ID)
         call erreur(status,.TRUE.,"def_var_dst_address_ID")
         status = NF90_DEF_VAR(fido2a,"src_address",NF90_INT,(/dimID_num_links/),src_address_ID)
         call erreur(status,.TRUE.,"def_var_src_address_ID")
                                   
        ! Attributs globaux       :
         status = NF90_PUT_ATT(fido2a,NF90_GLOBAL,"history","created using build_mozaic_OASIS_Ad01_Od01.f90")
         call erreur(status,.TRUE.,"put_att_GLOBAL_ID")
                                                      
        !Fin des definitions                          
         status = NF90_ENDDEF(fido2a)                   
         call erreur(status,.TRUE.,"fin_definition") 
                                                      
        !Valeurs prises par les variables :           
         status = NF90_PUT_VAR(fido2a,remap_matrix_ID,remap_matrix_o2a)
         call erreur(status,.TRUE.,"var_remap_matrix_ID")
         status = NF90_PUT_VAR(fido2a,dst_address_ID,dst_address_o2a)
         call erreur(status,.TRUE.,"var_dst_address_ID")
         status = NF90_PUT_VAR(fido2a,src_address_ID,src_address_o2a)
         call erreur(status,.TRUE.,"var_src_address_ID")
                                                      
        !Fin de l'ecriture                            
         status = NF90_CLOSE(fido2a)                    
         call erreur(status,.TRUE.,"final")         

end program modif



SUBROUTINE erreur(iret, lstop, chaine)
  ! pour les messages d'erreur
  USE netcdf
  INTEGER, INTENT(in)                     :: iret
  LOGICAL, INTENT(in)                     :: lstop
  CHARACTER(LEN=*), INTENT(in)            :: chaine
  !
  CHARACTER(LEN=80)                       :: message
  !
  IF ( iret .NE. 0 ) THEN
    WRITE(*,*) 'ROUTINE: ', TRIM(chaine)
    WRITE(*,*) 'ERROR: ', iret
    message=NF90_STRERROR(iret)
    WRITE(*,*) 'WHICH MEANS:',TRIM(message)
    IF ( lstop ) STOP
  ENDIF
  !
END SUBROUTINE erreur
