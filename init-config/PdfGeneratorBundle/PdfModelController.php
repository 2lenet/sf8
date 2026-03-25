<?php

declare(strict_types=1);


use App\Crudit\Config\PdfModelCrudConfig;
use Lle\CruditBundle\Controller\AbstractCrudController;
use Lle\CruditBundle\Controller\TraitCrudController;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/pdfmodel')]
class PdfModelController extends AbstractCrudController
{
    use TraitCrudController;

    public function __construct(PdfModelCrudConfig $config)
    {
        $this->config = $config;
    }
}
